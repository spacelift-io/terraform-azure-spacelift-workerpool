locals {
  worker_script_head = <<EOF
#!/bin/bash
spacelift () {(
set -e
  EOF

  worker_script_tail = <<EOF
echo "Updating packages" >> /var/log/spacelift/info.log
unattended-upgrade -d 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log

echo "Downloading Spacelift launcher" >> /var/log/spacelift/info.log
curl https://downloads.${var.domain_name}/spacelift-launcher --output /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log
echo "Importing public GPG key" >> /var/log/spacelift/info.log
curl https://keys.openpgp.org/vks/v1/by-fingerprint/175FD97AD2358EFE02832978E302FB5AA29D88F7 | gpg --import 2>>/var/log/spacelift/error.log
echo "Downloading Spacelift launcher checksum file and signature" >> /var/log/spacelift/info.log
curl https://downloads.${var.domain_name}/spacelift-launcher_SHA256SUMS --output spacelift-launcher_SHA256SUMS 2>>/var/log/spacelift/error.log
curl https://downloads.${var.domain_name}/spacelift-launcher_SHA256SUMS.sig --output spacelift-launcher_SHA256SUMS.sig 2>>/var/log/spacelift/error.log
echo "Verifying checksum signature..." >> /var/log/spacelift/info.log
gpg --verify spacelift-launcher_SHA256SUMS.sig 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log
retStatus=$?
if [ $retStatus -eq 0 ]; then
    echo "OK\!" >> /var/log/spacelift/info.log
else
    return $retStatus
fi
CHECKSUM=$(cut -f 1 -d ' ' spacelift-launcher_SHA256SUMS)
rm spacelift-launcher_SHA256SUMS spacelift-launcher_SHA256SUMS.sig
LAUNCHER_SHA=$(sha256sum /usr/bin/spacelift-launcher | cut -f 1 -d ' ')
echo "Verifying launcher binary..." >> /var/log/spacelift/info.log
if [[ "$CHECKSUM" == "$LAUNCHER_SHA" ]]; then
  echo "OK\!" >> /var/log/spacelift/info.log
else
  echo "Checksum and launcher binary hash did not match" >> /var/log/spacelift/error.log
  return 1
fi
echo "Making the Spacelift launcher executable" >> /var/log/spacelift/info.log
chmod 755 /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

# Get instance metadata
echo "Retrieving Azure VM Name" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_vm_name=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq ".compute.name")
echo "Retrieving Azure VM Resource ID" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_vm_resource_id=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq ".compute.resourceId")
echo "Retrieving Azure VMSS Name" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_vmss_name=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq ".compute.vmScaleSetName")

echo "Starting the Spacelift binary" >> /var/log/spacelift/info.log
/usr/bin/spacelift-launcher 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log
)}
spacelift
echo "Powering off in 15 seconds" >> /var/log/spacelift/error.log
sleep 15
poweroff
  EOF

  worker_script = base64encode(
    join("\n", [
      local.worker_script_head,
      var.configuration,
      local.worker_script_tail,
    ])
  )

  user_data = <<EOF
#!/bin/bash

# Write the launcher script out to a file in the `per-boot` folder to ensure it restarts if the VM is rebooted
echo "${local.worker_script}" | base64 --decode > /var/lib/cloud/scripts/per-boot/spacelift-boot.sh
chmod 744 /var/lib/cloud/scripts/per-boot/spacelift-boot.sh

/var/lib/cloud/scripts/per-boot/spacelift-boot.sh
  EOF
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = local.namespace
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  sku                 = var.vmss_sku

  instances      = var.vmss_instances
  admin_username = var.admin_username
  admin_password = var.admin_password

  dynamic "admin_ssh_key" {
    for_each = var.admin_public_key != null ? [0] : []
    content {
      username   = var.admin_username
      public_key = base64decode(var.admin_public_key)
    }
  }

  source_image_id = var.source_image_id

  dynamic "source_image_reference" {
    for_each = var.source_image_id == null ? [0] : []
    content {
      publisher = var.source_image_publisher
      offer     = var.source_image_offer
      sku       = var.source_image_sku
      version   = var.source_image_version
    }
  }

  dynamic "plan" {
    for_each = var.source_image_id == null ? [0] : []
    content {
      publisher = var.source_image_publisher
      name      = var.source_image_sku
      product   = var.source_image_offer
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "spacelift-worker-nic"
    primary = true

    ip_configuration {
      name                           = "internal"
      primary                        = true
      subnet_id                      = var.subnet_id
      application_security_group_ids = var.application_security_group_ids
    }
  }

  overprovision = var.overprovision

  dynamic "identity" {
    for_each = var.identity_type != null ? [0] : []
    content {
      type         = var.identity_type
      identity_ids = var.identity_ids
    }
  }

  custom_data = base64encode(local.user_data)

  scale_in_policy = "OldestVM"

  tags = merge(var.tags,
    {
      WorkerPoolID : var.worker_pool_id
    }
  )
}
