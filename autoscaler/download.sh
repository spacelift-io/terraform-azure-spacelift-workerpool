#!/usr/bin/env sh
set -e

code_version=$1
code_architecture=$2
downloadFolder=$3

# TODO:// might need to rename this after repo name changes
zip_name="ec2-workerpool-autoscaler_azurefunc_linux_${code_architecture}.zip"

if [ "$code_version" != "latest" ]; then
  # TODO:// might need to rename this after repo name changes
  download_url="https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/${zip_name}"
else
  tmpfile=$(mktemp /tmp/spacelift-request-headers.XXXXXX)
  if [ -n "${GITHUB_TOKEN}" ]; then
    # TODO:// might need to rename this after repo name changes
    request=$(curl -D "$tmpfile" -X GET --header "Authorization: Bearer ${GITHUB_TOKEN}" -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  else
    # TODO:// might need to rename this after repo name changes
    request=$(curl -D "$tmpfile" -X GET -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  fi
  ratelimit=$(cat "$tmpfile" | grep x-ratelimit-remaining | awk '{print $2}' | tr -d '\012\015')
  rm "$tmpfile"
  if [ "$ratelimit" = "0" ]; then
    echo "Github API rate limit exceeded, cannot find latest version. Please try again later or version pin the module."
    exit 1
  else
    echo "Github API rate limit remaining: '$ratelimit'"

    release=$(printf '%s' "$request" | jq -r --arg ZIP "$zip_name" '.assets[] | select(.name==$ZIP)')

    release_date=$(echo "$release" | jq -r '.created_at')
    download_url=$(echo "$release" | jq -r '.browser_download_url')

    echo "Downloading Details:"
    echo "  Release Name: $code_version"
    echo "  Release Date: $release_date"
    echo "  Download URL: $download_url"
  fi
fi

mkdir -p "$downloadFolder"
cd "$downloadFolder"
curl -L -O "$download_url"
