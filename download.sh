#!/usr/bin/env sh
set -ex

# Download the autoscaler binary from GitHub releases
# This script is similar to the AWS version but downloads the binary for Azure Function deployment

code_version=$1
code_architecture=$2
downloadFolder=$3

# Default values if not provided
if [ -z "$code_version" ]; then
  code_version="latest"
fi

if [ -z "$code_architecture" ]; then
  code_architecture="x86_64"
fi

if [ -z "$downloadFolder" ]; then
  downloadFolder="."
fi

# Map Azure architecture names to GitHub release names
# Azure uses x86_64/arm64, GitHub releases use amd64/arm64
case "$code_architecture" in
  x86_64)
    release_arch="amd64"
    ;;
  arm64)
    release_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: $code_architecture"
    exit 1
    ;;
esac

if [ "$code_version" != "latest" ]; then
  # If the code version is not latest, we don't need to hit the GitHub API
  download_url="https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/ec2-workerpool-autoscaler_linux_${release_arch}.zip"
else
  # Make a temporary file to store the headers in
  tmpfile=$(mktemp /tmp/spacelift-request-headers.XXXXXX)
  # If GITHUB_TOKEN is set, we can benefit from its higher rate limit
  if [ -n "${GITHUB_TOKEN}" ]; then
    request=$(curl -D "$tmpfile" -X GET --header "Authorization: Bearer ${GITHUB_TOKEN}" -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  else
    request=$(curl -D "$tmpfile" -X GET -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  fi
  ratelimit=$(cat "$tmpfile" | grep x-ratelimit-remaining | awk '{print $2}' | tr -d '\012\015')
  rm "$tmpfile"
  if [ "$ratelimit" = "0" ]; then
    echo "GitHub API rate limit exceeded, cannot find latest version. Please try again later or version pin the module."
    exit 1
  else
    echo "GitHub API rate limit remaining: '$ratelimit'"

    # Use printf here because echo will evaluate new lines which breaks the json formatting for jq
    release=$(printf '%s' "$request" | jq -r --arg ZIP "ec2-workerpool-autoscaler_linux_$release_arch.zip" '.assets[] | select(.name==$ZIP)')

    release_date=$(echo $release | jq -r '.created_at')
    download_url=$(echo $release | jq -r '.browser_download_url')

    echo "Downloading Details:"
    echo "  Release Name: $code_version"
    echo "  Release Date: $release_date"
    echo "  Download URL: $download_url"
  fi
fi

# Create download folder if it doesn't exist
mkdir -p "$downloadFolder"
cd "$downloadFolder"

# Download and extract the zip file
echo "Downloading autoscaler binary..."
curl -L -o ec2-workerpool-autoscaler_linux_${release_arch}.zip "$download_url"

echo "Extracting binary..."
unzip -o ec2-workerpool-autoscaler_linux_${release_arch}.zip

# Rename the binary to 'bootstrap' for Azure Function compatibility
if [ -f "bootstrap" ]; then
  echo "Binary 'bootstrap' extracted successfully"
else
  echo "Error: bootstrap binary not found in downloaded archive"
  exit 1
fi

# Clean up the zip file
rm ec2-workerpool-autoscaler_linux_${release_arch}.zip

echo "Download complete. Binary saved to: $downloadFolder/bootstrap"
