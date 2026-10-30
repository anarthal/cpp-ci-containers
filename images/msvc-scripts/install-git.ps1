#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Uses MinGit because it's more lightweight (no GUI).

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# Checksum from the release notes of https://github.com/git-for-windows/git
Expand-Verified -DestinationPath 'C:\git' `
    -Url 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip' `
    -Sha256 'E3BF78351FE777FBA47DDEE5950082F8A98BB0F02604FDC7BA3EE2CB68FFA877'
Add-MachinePath 'C:\git\cmd'

# Smoke test
Invoke-Checked git --version
