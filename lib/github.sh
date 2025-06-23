#!/usr/bin/env bash
#
# Donetick GitHub API Library
# Functions for interacting with GitHub releases
#

get_latest_release_info() {
  local repo="${1:-donetick/donetick}"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null
}

get_latest_version() {
  local release_info=$(get_latest_release_info)
  if [[ $? -eq 0 ]] && [[ -n "$release_info" ]]; then
    local version=$(echo "$release_info" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
    # Remove any leading 'v' from version if it exists
    echo "${version#v}"
  else
    echo ""
  fi
}

get_latest_tag() {
  local release_info=$(get_latest_release_info)
  if [[ $? -eq 0 ]] && [[ -n "$release_info" ]]; then
    echo "$release_info" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}'
  else
    echo ""
  fi
}

get_release_notes() {
  local version="$1"
  local repo="${2:-donetick/donetick}"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/v${version}" 2>/dev/null
}

check_breaking_changes() {
  local version="$1"
  msg_info "Checking for breaking changes in v${version}..."
  
  local release_notes=$(get_release_notes "$version")
  if [[ $? -eq 0 ]] && [[ -n "$release_notes" ]]; then
    local body=$(echo "$release_notes" | grep -o '"body":"[^"]*"' | sed 's/"body":"//;s/"$//' | sed 's/\\n/\n/g')
    
    # Check for breaking change indicators
    if echo "$body" | grep -qi -E "(breaking|migration|config.change|incompatible|deprecated|database.migration)"; then
      msg_warn "Potential breaking changes detected in v${version}!"
      msg_warn "Release notes excerpt:"
      echo "$body" | head -10
      msg_warn "Please review the full release notes at:"
      msg_warn "https://github.com/donetick/donetick/releases/tag/v${version}"
      msg_warn "Your configuration backup will be preserved for manual review."
      return 1
    fi
  fi
  return 0
}

get_download_url() {
  local version_tag="$1"
  local architecture="$2"
  echo "https://github.com/donetick/donetick/releases/download/${version_tag}/donetick_Linux_${architecture}.tar.gz"
}

check_for_updates() {
  msg_info "Checking for updates..."
  
  local current_version=$(get_current_version)
  local latest_version=$(get_latest_version)
  
  if [[ -z "$latest_version" ]]; then
    msg_warn "Could not fetch latest version information from GitHub."
    return 1
  fi
  
  msg_info "Current version: ${current_version}"
  msg_info "Latest version:  ${latest_version}"
  
  if [[ "$current_version" == "none" ]]; then
    msg_info "No existing installation found. Will perform fresh installation."
    return 0
  fi
  
  version_compare "$current_version" "$latest_version"
  local result=$?
  
  case $result in
    0)
      msg_ok "Already running the latest version (${current_version})"
      return 1
      ;;
    1)
      msg_warn "Current version (${current_version}) is newer than latest release (${latest_version})"
      return 1
      ;;
    2)
      msg_info "Update available: ${current_version} → ${latest_version}"
      return 0
      ;;
  esac
}
