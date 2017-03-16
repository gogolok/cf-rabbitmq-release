#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
source spec/bash/test_helpers

# Creates a new test user for each run
# We expect the container to be flushed between deployments which
# will drop the test user.
local testuser="testuser-$(date +%s)"
sudo adduser --disabled-password --no-create-home --gecos "" $testuser

pathstat() {
  local path=${1:?path to check}

  sudo stat "$path" -c '%A %U:%G'
}

check_path() {
    local path=${1:?path to check}
    local mode=${2:?mode to match}

    expect_to_equal "$(pathstat $path)" "$mode $testuser:$testuser"
}

T_creates_missing_directory_and_sets_permissions() {
  local topdir=$(mktemp -d)

  local destination_dir="${topdir}/one/two"
  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  check_path "$destination_dir" "drwxr-x---"
}

T_assign_ownership_and_permissions_for_an_existing_directory() {
  local topdir=$(mktemp -d)

  local destination_dir="${topdir}/one/two"
  local nested_dir="$destination_dir/three/four"
  mkdir -p "$nested_dir"
  touch "$nested_dir/a-file"
  touch "$nested_dir/an-executable-file"
  chmod ug+x "$nested_dir/an-executable-file"

  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  check_path "$destination_dir" "drwxr-x---"
  check_path "$nested_dir" "drwxrwx---"
  check_path "$nested_dir/a-file" "-rw-rw----"
  check_path "$nested_dir/an-executable-file" "-rwxrwx---"
}

T_does_not_follow_symbolic_links() {
  local topdir=$(mktemp -d)

  local linked_to="$topdir/linked_to"
  touch ${linked_to}
  chmod a+rw ${linked_to}
  local original_stat="$(pathstat $linked_to)"

  local destination_dir="${topdir}/one/two"
  local linked_from="$destination_dir/linked_from"
  mkdir -p "$destination_dir"
  ln -s ${linked_to} ${linked_from}

  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  check_path "$destination_dir" "drwxr-x---"
  expect_to_equal "$(pathstat $linked_to)" "$original_stat"
}
