#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs the MySQL server the tests run against, and registers it as a service.
# See build-msvc.dockerfile.

$ErrorActionPreference = 'Stop'

# Downloaded from the CDN rather than through chocolatey, whose package hardcodes
# a dev.mysql.com URL: that host is a redirector with bot protection in front of
# it, and it answers 403 to CI runners. This is the file it redirects to, and the
# checksum is the one the chocolatey package pins, so the bytes are the same
# either way. Only the three values below change to move to another version.
$version = '8.0.20'
$url = "https://cdn.mysql.com/archives/mysql-8.0/mysql-$version-winx64.zip"
$sha256 = 'B9A7592AC170A6C55CE4F20C16E120C789D3D89342EA5681362311E118103A8A'

# The layout and defaults the chocolatey package produced, kept so that nothing
# downstream has to change: same location, same data directory, same service name,
# and a passwordless root, which is what the CI scripts connect as.
$installDir = 'C:\tools\mysql\current'
$dataDir = 'C:\ProgramData\MySQL\data'
$serviceName = 'MySQL'
$zip = 'C:\tmp\mysql.zip'
$extracted = 'C:\tmp\mysql'

Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash
if ($actual -ne $sha256) { throw "mysql.zip checksum mismatch: $actual" }

Expand-Archive -Path $zip -DestinationPath $extracted
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $installDir) | Out-Null
Move-Item (Join-Path $extracted "mysql-$version-winx64") $installDir
Remove-Item -Recurse -Force $extracted, $zip

# The server reads basedir and datadir from here and its SSL settings from
# C:\my.cnf; both are in its default search path. Forward slashes are valid in
# MySQL option files.
$iniPath = Join-Path $installDir 'my.ini'
@(
    '[mysqld]'
    'basedir={0}' -f ($installDir -replace '\\', '/')
    'datadir={0}' -f ($dataDir -replace '\\', '/')
    'port=3306'
) | Set-Content -Path $iniPath -Encoding ascii

$mysqld = Join-Path $installDir 'bin\mysqld.exe'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
& $mysqld "--defaults-file=$iniPath" --initialize-insecure
if ($LASTEXITCODE -ne 0) { throw 'mysqld --initialize-insecure failed' }

& $mysqld --install $serviceName
if ($LASTEXITCODE -ne 0) { throw 'mysqld --install failed' }

# Check the server comes up and answers as root before shipping the image, rather
# than letting every CI job discover it can't connect. Stopped again afterwards so
# the layer isn't committed with a half-written data directory; the service starts
# with the container, since it's registered to start automatically.
Start-Service $serviceName
& (Join-Path $installDir 'bin\mysql.exe') -u root --batch --skip-column-names -e 'SELECT VERSION()'
if ($LASTEXITCODE -ne 0) { throw 'the server did not answer as root' }
Stop-Service $serviceName

# Written through the registry rather than with setx, which truncates PATH at
# 1024 characters.
$path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$installDir\bin;$path", 'Machine')
