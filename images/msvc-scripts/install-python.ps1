#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs Python, which runs the CI scripts. See ../build-msvc.dockerfile.
#
# The embeddable package is a third of the size but ships without pip, so this is
# the regular installer with the parts a CI image has no use for left out: the
# test suite, the docs, tkinter and IDLE, the headers and libs for embedding, and
# the py.exe launcher.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# Checksum from https://www.python.org/downloads/release/python-3152/
$version = '3.15.2'
$installDir = 'C:\python'
$installer = 'C:\tmp\python.exe'
Get-Verified -OutFile $installer `
    -Url "https://www.python.org/ftp/python/$version/python-$version-amd64.exe" `
    -Sha256 '06E225A228191B0F4D1DCF6905FBB21BF9F6970D13A2EC63137AB9BEE76F15AA'
Invoke-Installer -Path $installer -Arguments @(
    '/quiet', 'InstallAllUsers=1', "TargetDir=$installDir",
    'Include_test=0', 'Include_doc=0', 'Include_tcltk=0', 'Include_dev=0', 'Include_launcher=0'
)
Remove-Item -Force $installer
Add-MachinePath (Join-Path $installDir 'Scripts') # pip
Add-MachinePath $installDir

# requests, used by the examples under example/private
Invoke-Checked python -m pip install --no-cache-dir --disable-pip-version-check requests

Invoke-Checked python --version
