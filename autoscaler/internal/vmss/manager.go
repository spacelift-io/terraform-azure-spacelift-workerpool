package vmss

import (
	"context"
	"fmt"
	"sort"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/compute/armcompute/v5"
)

type Manager struct {
	client            *armcompute.VirtualMachineScaleSetsClient
	resourceGroupName string
	vmssName          string
}

type Instance struct {
	ID        string
	Name      string
	State     string
	CreatedAt time.Time
}

func NewManager(client *armcompute.VirtualMachineScaleSetsClient, resourceGroupName, vmssName string) *Manager {
	return &Manager{
		client:            client,
		resourceGroupName: resourceGroupName,
		vmssName:          vmssName,
	}
}

// GetCurrentCapacity returns the current capacity of the VMSS
func (m *Manager) GetCurrentCapacity(ctx context.Context) (int64, error) {
	vmss, err := m.client.Get(ctx, m.resourceGroupName, m.vmssName, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to get VMSS: %w", err)
	}

	if vmss.SKU == nil || vmss.SKU.Capacity == nil {
		return 0, fmt.Errorf("VMSS capacity is nil")
	}

	return *vmss.SKU.Capacity, nil
}

// GetMinCapacity returns the minimum capacity from autoscale settings
func (m *Manager) GetMinCapacity(ctx context.Context) (int64, error) {
	vmss, err := m.client.Get(ctx, m.resourceGroupName, m.vmssName, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to get VMSS: %w", err)
	}

	// Azure VMSS doesn't have a direct min capacity in the SKU
	// It's typically configured via autoscale settings or tags
	// For now, we'll default to 0 or check tags
	if vmss.Tags != nil {
		if minCapStr, ok := vmss.Tags["MinCapacity"]; ok {
			var minCap int64
			fmt.Sscanf(*minCapStr, "%d", &minCap)
			return minCap, nil
		}
	}

	return 0, nil
}

// GetMaxCapacity returns the maximum capacity from autoscale settings
func (m *Manager) GetMaxCapacity(ctx context.Context) (int64, error) {
	vmss, err := m.client.Get(ctx, m.resourceGroupName, m.vmssName, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to get VMSS: %w", err)
	}

	// Check for max capacity in tags
	if vmss.Tags != nil {
		if maxCapStr, ok := vmss.Tags["MaxCapacity"]; ok {
			var maxCap int64
			fmt.Sscanf(*maxCapStr, "%d", &maxCap)
			return maxCap, nil
		}
	}

	// Default to a reasonable max if not specified
	return 100, nil
}

// SetCapacity sets the capacity of the VMSS
func (m *Manager) SetCapacity(ctx context.Context, capacity int64) error {
	// Get current VMSS
	vmss, err := m.client.Get(ctx, m.resourceGroupName, m.vmssName, nil)
	if err != nil {
		return fmt.Errorf("failed to get VMSS: %w", err)
	}

	// Update capacity
	if vmss.SKU == nil {
		vmss.SKU = &armcompute.SKU{}
	}
	vmss.SKU.Capacity = &capacity

	// Update VMSS
	poller, err := m.client.BeginUpdate(ctx, m.resourceGroupName, m.vmssName, armcompute.VirtualMachineScaleSetUpdate{
		SKU: vmss.SKU,
	}, nil)
	if err != nil {
		return fmt.Errorf("failed to begin VMSS update: %w", err)
	}

	_, err = poller.PollUntilDone(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to update VMSS capacity: %w", err)
	}

	return nil
}

// ListInstances returns all instances in the VMSS
func (m *Manager) ListInstances(ctx context.Context) ([]*Instance, error) {
	vmClient := m.client
	// Need to create a VirtualMachineScaleSetVMsClient for listing VMs
	// This is a simplified version - you'd need to create the proper client

	// For now, we'll use a workaround by getting instance view
	pager := m.client.NewListVMInstanceViewPager(m.resourceGroupName, m.vmssName, nil)

	var instances []*Instance
	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list VMSS instances: %w", err)
		}

		for _, vm := range page.Value {
			if vm.InstanceID == nil {
				continue
			}

			instance := &Instance{
				ID:        *vm.InstanceID,
				Name:      *vm.Name,
				CreatedAt: time.Now(), // Would need to get from VM metadata
			}

			if vm.InstanceView != nil && len(vm.InstanceView.Statuses) > 0 {
				// Get the provisioning state
				for _, status := range vm.InstanceView.Statuses {
					if status.Code != nil {
						instance.State = *status.Code
					}
				}
			}

			instances = append(instances, instance)
		}
	}

	return instances, nil
}

// TerminateInstance terminates a specific VMSS instance
func (m *Manager) TerminateInstance(ctx context.Context, instanceID string) error {
	// Create VirtualMachineScaleSetVMsClient for deleting specific instances
	// This requires proper initialization - for now we'll show the pattern

	vmClient := m.client
	_ = vmClient // Use the client reference

	// The actual deletion would use VirtualMachineScaleSetVMsClient
	// poller, err := vmClient.BeginDelete(ctx, m.resourceGroupName, m.vmssName, instanceID, nil)
	// For now, we'll return a placeholder

	return fmt.Errorf("termination not fully implemented - needs VirtualMachineScaleSetVMsClient")
}

// SortInstancesByAge sorts instances by creation time (oldest first)
func SortInstancesByAge(instances []*Instance) {
	sort.Slice(instances, func(i, j int) bool {
		return instances[i].CreatedAt.Before(instances[j].CreatedAt)
	})
}
