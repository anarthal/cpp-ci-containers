#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# There is no Windows MySQL container, and we can't mix Linux and Windows containers
# in most CIs. So we need to install MySQL locally in the Windows machine.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# Use the CDN directly, rather than the recommended URL, because the latter
# tends to fail with 403 in automated builds
$version = '8.0.20'
$url = "https://cdn.mysql.com/archives/mysql-8.0/mysql-$version-winx64.zip"
$sha256 = 'B9A7592AC170A6C55CE4F20C16E120C789D3D89342EA5681362311E118103A8A'

$installDir = "C:\mysql-$version-winx64" # archive expands to this name
$dataDir = 'C:\ProgramData\MySQL\data'
$serviceName = 'MySQL'
$sslDir = 'C:/ssl' # the dockerfile copies the certificates here

Expand-Verified -Url $url -Sha256 $sha256 -DestinationPath 'C:\'

# Generate the config file read by mysqld
$iniPath = Join-Path $installDir 'my.ini'
@(
    '[mysqld]'
    'basedir={0}' -f ($installDir -replace '\\', '/')
    'datadir={0}' -f ($dataDir -replace '\\', '/')
    'port=3306'
    "ssl-ca=$sslDir/ca-cert.pem"
    "ssl-cert=$sslDir/server-cert.pem"
    "ssl-key=$sslDir/server-key.pem"
) | Set-Content -Path $iniPath -Encoding ascii

# Create the data dir
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

# MySQL initialization
$mysqld = Join-Path $installDir 'bin\mysqld.exe'
Invoke-Checked $mysqld "--defaults-file=$iniPath" --initialize-insecure
Invoke-Checked $mysqld --install $serviceName

# Smoke test
Start-Service $serviceName
Invoke-Checked (Join-Path $installDir 'bin\mysql.exe') -u root --batch --skip-column-names -e 'SELECT VERSION()'
Stop-Service $serviceName

Add-MachinePath (Join-Path $installDir 'bin')
