#!/bin/sh
# Copyright 2022 Oliver Smith
# SPDX-License-Identifier: AGPL-3.0-or-later
set -e
DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$DIR/.."

# Make sure that the work folder format is up to date, and that there are no
# mounts from aborted test cases (#1595)
./pmbootstrap.py work_migrate
./pmbootstrap.py -q shutdown

# Install needed packages
echo "Initializing Alpine chroot (details: 'pmbootstrap log')"
./pmbootstrap.py -q chroot -- apk -q add \
	shellcheck \
	python3 \
	py3-flake8 || return 1

rootfs_native="$(./pmbootstrap.py config work)/chroot_native"
command="$rootfs_native/lib/ld-musl-$(uname -m).so.1"
command="$command --library-path=$rootfs_native/lib:$rootfs_native/usr/lib"
shellcheck_command="$command $rootfs_native/usr/bin/shellcheck"
flake8_command="$command $rootfs_native/usr/bin/python3 $rootfs_native/usr/bin/flake8"

# Shell: shellcheck
find . -name '*.sh' |
while read -r file; do
	echo "Test with shellcheck: $file"
	cd "$DIR/../$(dirname "$file")"
	$shellcheck_command -e SC1008 -x "$(basename "$file")"
done

# Python: flake8
# F401: imported, but not used, does not make sense in __init__ files
# E402: module import not on top of file, not possible for testcases
# E722: do not use bare except
cd "$DIR"/..
echo "Test with flake8: *.py"
# Note: omitting a virtualenv if it is here (e.g. gitlab CI)
py_files="$(find . -not -path '*/venv/*' -name '*.py')"
_ignores="E402,E722,W504,W605"
# shellcheck disable=SC2086
$flake8_command --exclude=__init__.py --ignore "$_ignores" $py_files
# shellcheck disable=SC2086
$flake8_command --filename=__init__.py --ignore "F401,$_ignores" $py_files

# Done
echo "Success!"
