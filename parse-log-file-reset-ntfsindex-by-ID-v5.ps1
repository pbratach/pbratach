# Author:  Paul Bratach
# Description:
#   This script will check for lines containing "Can't find the file by ID|Can't link the file by ID"
# Version 3 updates
#    Added parameter check to run against a specific share
#    Updated script to search all logs for the specific share
# Version 4 updates
#    Removed trailing space from $filename
# Version 5
#    Changed output filename to C:\Temp\complete-hcpgw-reset-ntfsindex-by-ID-$archiveid.txt
#    Added archiveId to temp file C:\Temp\hcpgw-reset-ntfsindex-by-ID-raw-$archiveid.txt
#    Remove the raw output file before exiting
# Syntax:
#    .\parse-log-file-reset-ntfsindex-by-ID-v5.ps1 <archiveId>

switch ( $args.count ) {
	0 { 
		Write-Host -ForegroundColor Red "Syntax $myscriptname <archive-id>"
		exit
	}
	1 { 
		$archiveid = $($args[0])
		break
	}
	Default {
		Write-Host -ForegroundColor Red "Syntax $myscriptname <archive-id>"
		exit
	}
}

#foreach ( $line in Select-String C:\SAM\var\log\log-$archiveid.txt* -Pattern "Can't find the file by ID|Can't link the file by ID" ) {
foreach ( $line in Select-String "C:\Users\pbratach\Downloads\HCP_Gateway_Log_Collected_ESCGTW3_07-31-2024_01-11\SAM\var\log\log-$archiveid.txt*" -Pattern "Can't find the file by ID|Can't link the file by ID" ) {
	Write-Host Parsing line: $line
	# Remove everything before "the file by ID"
	$separator = "the file by ID"
	$a,$b=$line -split $separator

#	Write-Host DEBUG B is $b 
	$fsid = $b.trim()

	Write-Output $fsid | Out-File -FilePath "C:\Temp\hcpgw-reset-ntfsindex-by-ID-raw-$archiveid.txt" -Append
}	
Get-Content "C:\Temp\hcpgw-reset-ntfsindex-by-ID-raw-$archiveid.txt" | sort | get-unique > "C:\Temp\complete-hcpgw-reset-ntfsindex-by-ID-$archiveid.txt"

if ( Test-Path "C:\Temp\hcpgw-reset-ntfsindex-by-ID-raw-$archiveid.txt" ) {
  Remove-Item -Path "C:\Temp\hcpgw-reset-ntfsindex-by-ID-raw-$archiveid.txt"
}
