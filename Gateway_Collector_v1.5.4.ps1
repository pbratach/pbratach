# Description:
#   Powershell version of Paul Riley Gateway_Collector.bat
# Author:
#   Paul Bratach
# Modified Date: 26 June 2024
# Updates
#   Version: 1.5.3
#     Converted from Windows Batch file to Powershell
#   Version: 1.5.4
#     Add hostname to name of working folder and zip file

Write-Output "***********************"
Write-Output "IPG is used to throttle the copy tasks edit the number below to amend the speed"
Write-Output "IPG:0 = Unlimited"
Write-Output "IPG:45 = 10mb"
Write-Output "IPG:58 = 8mb" 
Write-Output "IPG:78 = 6mb"
Write-Output "IPG:120 = 4mb"
Write-Output "IPG:240 = 2mb"
Write-Output "***********************"
# Clear-Host
$Speed="IPG:45"
Write-Output "Current Speed is $Speed"
Write-Output "***********************"

function DELETE-FILE($delfilename)
{
	if (Test-Path $delfilename) {
		Remove-Item $delfilename
	}
}

function DB-QUERY($query, $header)
{
	Write-Output "Executing MariaDB Database query <$header>"
	$collectoroutput = "$query" | &$dbProgram --user=root --password=$dbRootPass --ssl -B -s -t -vv --database=$dbName  
	if (Test-Path -Path "$tempDBfile") {
		# file with path $path doesn't exist
		$content = Get-Content "$tempDBfile" -Raw
		$prepend = $header
		$content = $prepend + [Environment]::NewLine + $content
		Set-Content "$tempDBfile" $content		
		$From = Get-Content -Path "$tempDBfile"		
		if (Test-Path -Path "$MDBoutput") {
			Add-Content "$MDBoutput" -Value $From
		}
		else {
			Copy-Item "$tempDBfile" -Destination "$MDBoutput"
		}
#		Write-Output "DEBUG Deleting $tempDBfile"
		Remove-Item "$tempDBfile"
	}
	else {
		Write-Output "$query" | Out-File -FilePath $MDBoutput -Append -Encoding ASCII
		Write-Output "$collectoroutput" | Out-File -FilePath $MDBoutput -Append -Encoding ASCII
		Write-Output " " | Out-File -FilePath $MDBoutput -Append -Encoding ASCII
	}
}

function GW-LOGS
{
    Write-Output " Starting Gateway Log Collection"
	$baseworkfolder = "Working_Folder"
	if ( Test-Path -Path $baseworkfolder ) {
		Write-Output "$baseworkfolder already exists"
	}
	else {
		New-Item "Working_Folder" -ItemType "directory" | Out-Null
	}
	New-Item "$basewfname" -ItemType "directory" | Out-Null
	New-Item "D:\$basewfname\MariaDB\DataBase_Commands" -ItemType "directory" | Out-Null
    #using get-item instead because some of the folders have '[' or ']' character and Powershell throws exception trying to do a get-acl or set-acl on them.
    $item = gi -literalpath "D:\$basewfname\MariaDB\DataBase_Commands" 
    $acl = $item.GetAccessControl() 
    $permission = "Everyone","FullControl","Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($rule)
    $item.SetAccessControl($acl)

	New-Item "$basewfname\Windows\Disks" -ItemType "directory" | Out-Null
	Write-Output "Version 1.5.4" > "$basewfname\version.txt"

	Write-Output "*********************************************************"
	Write-Output "*** Ensure the Gateway_Collector_SQL_v1.5.4.sql file   **" 
	Write-Output "*** is in same location as the Collector script        **"
	Write-Output "*********************************************************"
	Write-Output " "
	Write-Output "***************************************************************"
	Write-Output "****** Copying MariaDB Commands Output to Working_Folder ******"
	Write-Output "***************************************************************"
	Write-Output " "

	#  Read sam.properties
	$SamProperties = 'C:\SAM\etc\sam\sam.properties'
	$samTool= "C:\Program Files\SAM\SAM-Tool.exe"

	# reread the properties
	$properties = Select-String -Pattern "(?-s)(?<=$($property)=).+" -AllMatches -CaseSensitive -Encoding UTF8 -Path $SamProperties 
	$properties = $properties  -Replace '\\','/' 

	ForEach ($property in $properties) {
		$property = ($property -split ":", 4)[3]
		$key = ($property -split "=",2)[0]
		$value = ($property -split "=",2)[1].Replace("`"","")    
		
		if ( $key -like 'database.password' ) {    
		  $result = & "$samTool" --decrypt "$value"   
		  if ( $result -ne $null ) {
			 $dbUserPass = ($result -split ":", 2)[1].trim()               
		  }
		} 
		elseif ($key -like 'database.root.password' ) {
		  $result = & "$samTool" --decrypt "$value"  
		  if ( $result -ne $null ) {      
			 $dbRootPass = ($result -split ":", 2)[1].trim()              
		  }
		}
		elseif ($key -like 'database.username' ) {
		   $dbUserName = $value
		}
		elseif ($key -like 'database.name' ) {
		   $dbName = $value
		}    
		elseif ($key -like 'database.program' ) {
		   $dbProgram = $value.Trim()
		}   
		elseif ($key -like 'database.dump' ) {
		   $dbDump = $value
		}   
		elseif ($key -like 'data.folder' ) {
		   $datafolder = $value
		}   
	}

	Write-Output "If you don't see the HCP_Gateway_SQL_Commands.txt file, then the Gateway Collector_SQL.sql database script did not run" >> "D:\$basewfname\MariaDB\DataBase_Commands\Read_Me.txt"

	$tempDBfile="D:\\$dbasewfname\\MariaDB\\DataBase_Commands\\HCP_Gateway_SQL_Output.txt"
	$MDBoutput="D:\\$dbasewfname\\MariaDB\\DataBase_Commands\\HCP_Gateway_SQL_Commands.txt"
	$MDBoutputfolder="D:\\$dbasewfname\\MariaDB\\DataBase_Commands"
# Create the Temp folder used for the MariaDB queries
	if (-Not (Test-Path -Path "D:\Temp")) {
		New-Item -Path "D:\Temp" -ItemType Directory
		$add_rule = (New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","FullControl", "Allow"));
		$acl.SetAccessRuleProtection($true,$true)
		$acl.SetAccessRule($add_rule)
		Set-ACL "D:\Temp" $acl;
	}
		
	foreach($line in Get-Content "Gateway_Collector_SQL_v1.5.4.sql" ) {
		# Run the Gateway Collector_SQL.sql script
#		Write-Output "DEBUG: Processing line <$line>"
		
		if ( $line.Contains("select") -and (-Not $line.Contains("group_concat")) ) {
			$sql = $line + " INTO OUTFILE '$tempDBfile' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\r\n';"
			DB-Query $sql $line
		}		
		elseif ( $line.Contains("source D:") ) {
			$g, $h = $line -Split "Source "
			$line2, $j = $h.Split(";")
			$line2 = $line2.replace('/','\')
#			Write-Output "DEBUG G is <$g>, h is <$h>, line2 is <$line2>"
			foreach($line3 in Get-Content $line2 ) {
				# Split the string into individual queries using semicolons as delimiters
#				Write-Output "DEBUG: line3 is <$line3>"
				$individualQueries = $line3.Split(';')

				# Remove any empty strings that might be present after splitting
				$individualQueries = $individualQueries | Where-Object { $_.Trim() }

				# Loop through each individual query
				foreach ($query3 in $individualQueries) {
				# Process or display each query here
#				Write-Host "DEBUG: Extracted Query: $query3"
				if ( $query3.Contains("select") ) {
							$sql3 = $query3 + " INTO OUTFILE '$tempDBfile' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\r\n';"
						} else {
							$sql3 = $query3 + ";"
						}
						DB-Query $sql3 $query3
				}
			}
		} else {
			$sql = $line + ";"
			DB-Query $sql $line
		}
	}
	
	Write-Output " "
	Write-Output "**********************************************************"
	Write-Output "********* Copying SAM Logs to Working_Folder *************"
	Write-Output "***********************************************************"
	Write-Output " "

	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\SAM\var\log" "$basewfname\SAM\var\log"
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\SAM\etc\sam" "$basewfname\SAM\etc\sam"

	Write-Output "**********************************************************"
	Write-Output "********* Copying MariaDB Logs to Working_Folder *********"
	Write-Output "**********************************************************"
	Write-Output " "

	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "$datafolder" "$basewfname\MariaDB\data" *.err
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "$datafolder" "$basewfname\MariaDB\data" my.ini
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "$MDBoutputfolder" "$basewfname\MariaDB\data" HCP_Gateway_SQL_Commands.txt

	Write-Output "**********************************************************"
	Write-Output "******** Copying Wildfly Logs to Working_Folder **********"
	Write-Output "**********************************************************"
	Write-Output " "

	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\opt\wildfly\standalone\log" "$basewfname\wildfly\opt\wildfly\standalone\log"

	Write-Output "********************************************************"
	Write-Output "** Copying Windows Disk sizes Logs to Working_Folder ***"
	Write-Output "********************************************************"
	Write-Output " "

	net share >>"$basewfname\Windows\Disks\Net Share.txt"
	fsutil volume diskfree C:  >>"$basewfname\Windows\Disks\C_DriveSizes.txt" 
	fsutil volume diskfree D:  >>"$basewfname\Windows\Disks\D_DriveSizes.txt" 
	fsutil volume diskfree E:  >>"$basewfname\Windows\Disks\E_DriveSizes.txt" 
	fsutil volume diskfree F:  >>"$basewfname\Windows\Disks\F_DriveSizes.txt" 
	fsutil volume diskfree G:  >>"$basewfname\Windows\Disks\G_DriveSizes.txt" 
	Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID,@{'Name' = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} >>"$basewfname\Windows\Disks\Free_Drive_Space.txt"

	Write-Output "**************************************************************************"
	Write-Output "********* Copying Windows Services Information to Working_Folder *********"
	Write-Output "**************************************************************************"
	Write-Output " "

	& sc.exe query Wildfly >>"$basewfname\Windows\Services_Task_List.txt"
	& sc.exe query SAMVFS >>"$basewfname\Windows\Services_Task_List.txt"
	& sc.exe query MariaDB >>"$basewfname\Windows\Services_Task_List.txt"

	Write-Output "******************************************************"
	Write-Output "********* Collecting CPU Load for 10 seconds *********"
	Write-Output "******************************************************"
	Write-Output " "
	wmic cpu get loadpercentage /every:2 /repeat:5 >>"$basewfname\Windows\CPU_Load.txt"

	tasklist >>"$basewfname\Windows\Services_Task_List.txt"
	systeminfo >>"$basewfname\Windows\System_Information.txt"
	ipconfig /all >>"$basewfname\Windows\network.txt"
	dir env: >>"$basewfname\Windows\Windows_Environment_variables.txt"

	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\Windows\System32\winevt\Logs" "$basewfname\Windows\Events" Application.evtx 
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\Windows\System32\winevt\Logs" "$basewfname\Windows\Events" Setup.evtx 
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "C:\Windows\System32\winevt\Logs" "$basewfname\Windows\Events" System.evtx 

	get-hotfix >> "$basewfname\Windows\HotFix.txt"

	get-package |Format-Table  >> "$basewfname\Windows\Installed_Packages.txt"
	get-package |Format-Table -autosize >> "$basewfname\Windows\Installed_Packages-autosize.txt"

	Get-MpPreference | Select-Object -Property ExclusionPath -ExpandProperty ExclusionPath >> "$basewfname\Windows\Anti_Virus_Exclusion_list.txt"

	Write-Output "***********************************************"
	Write-Output "***** Zipping Up Logs Collected ***************"
	Write-Output "***********************************************"
	Write-Output " "

	cd "Working_Folder"

#	Zip up then remove all the Gateway log temporary files
	& "C:\Program Files\7-Zip\7z.exe" a -m0=lzma -mmt=off -mhe=on -mx=3 "HCP_Gateway_Log_Collected_$cname`_$timestamp"
	cd..
	Remove-Item -Path "$basewfname" -Recurse -Force

#	Zip up then remove the WOrking_Folder
	& C:\Windows\System32\robocopy.exe /TEE /S /E /R:0 /$Speed "Working_Folder" "Collection\HCP_Gateway_Log_Collected_$cname`_$timestamp"
	Remove-Item -Path "Working_Folder" -Recurse -Force
	
#	Remove all the MariaDB temporary files
	DELETE-FILE "D:\Temp\Gateway_all_share_event_tables.sql"
	DELETE-FILE "D:\Temp\Gateway_all_share_migration_tables_recordcount.sql"
	DELETE-FILE "D:\Temp\Gateway_all_share_migration_tables.sql"
	DELETE-FILE "D:\Temp\Gateway_all_share_fs_tables_recordcount.sql"
	DELETE-FILE "D:\Temp\Gateway_all_share_fs_tables_details.sql"
	DELETE-FILE "D:\Temp\Gateway_show_create_fs_tables.sql"
	DELETE-FILE "D:\Temp\Gateway_show_create_map_tables.sql"
	DELETE-FILE "D:\Temp\Gateway_show_create_ntfs_tables.sql"
	DELETE-FILE "D:\Temp\Gateway_show_create_object_tables.sql"
	DELETE-FILE "$tempDBfile"
	DELETE-FILE "$MDBoutput"
	Remove-Item -Path D:\Working_Folder -Recurse -Force

	Write-Output " "
	Write-Output "***********************************"
	Write-Output "****** Collection Completed *******"
	Write-Output "***********************************"
	Write-Output " "
	Write-Output " "
	Write-Output "**********************************************"
	Write-Output "** Please Upload the 7z Zip file in the new **"
	Write-Output "** Windows Explorer window to your case     **"
	Write-Output "**********************************************"
	$logpath=Get-Location
	Write-Output "Log File Name: HCP_Gateway_Log_Collected_$cname`_$timestamp.7z"
	Write-Output "Log Location: $logpath\Collection\HCP_Gateway_Log_Collected_$cname`_$timestamp\HCP_Gateway_Log_Collected_$cname`_$timestamp.7z"
	Write-Output " "
	Write-Output " "

	& explorer "Collection\HCP_Gateway_Log_Collected_$cname`_$timestamp"
	Write-Output " "
	Write-Output " "
	Write-Output "********************************"
	Write-Output "** Press any key to continue ***"
	Write-Output "********************************"
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

function FREE-SPACE
{
    Write-Output "Calculating FREE-SPACE"
	$directory1 = Get-Item "C:\SAM\var\log"
	$directory2 = Get-Item "C:\opt\wildfly\standalone\log"

	$( Get-ChildItem "C:\SAM\var\log" | Measure-Object -Sum Length | Select-Object @{Name='Log File Path'; Expression={$directory1.FullName}}, @{Name='Files'; Expression={$_.Count}},  @{Name='Size in GB'; Expression={[math]::Round($_.Sum/1024/1024/1024,2)}} ) | Out-Host
	$( Get-ChildItem "C:\opt\wildfly\standalone\log" | Measure-Object -Sum Length | Select-Object @{Name='Log File Path'; Expression={$directory2.FullName}}, @{Name='Files'; Expression={$_.Count}},  @{Name='Size in GB'; Expression={[math]::Round($_.Sum/1024/1024/1024,2)}} ) | Out-Host

	Write-Output "*************************************************************************************************"
	Write-Output "*** Currently running on drive $currentdrive                                                              ***"
	Write-Output "*** Once you have confirmed your disk has enough free space you may continue to the main MENU ***" 
	Write-Output "*************************************************************************************************"
	#	Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID,@{'Name' = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} | Write-Output
	#	Get-WmiObject -Class Win32_LogicalDisk -ComputerName localhost | ? {$_. DriveType -eq 3} | select DeviceID, {$_.Size /1GB}, {$_.FreeSpace /1GB} 
	$( Get-WmiObject -Class Win32_LogicalDisk -ComputerName localhost | ? {$_. DriveType -eq 3} | select DeviceID, @{'Name' = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} ) | Out-Host

	do {
	# Prompt user for option
		Write-Output " Enter C to continue "
		Write-Output " Enter E to EXIT script"
		$a = Read-Host -Prompt "`n Enter your option "
	} until (($a -eq "C") -or ($a -eq "c") -or ($a -eq "E") -or ($a -eq "e"))
	$host.UI.RawUI.ForegroundColor = "White"

	switch($a)
	{
		E{Exit}
		e{Exit}
	}	
	return
}

# Start of main code
$currentfolder = (Get-Item .).FullName

Write-Output " "
Write-Output "******************************************" 
Write-Output "******* HCP Gateway Log Working_Folder ***"
Write-Output "******* $currentfolder\Working_Folder         ***"
Write-Output "******************************************"
#	Clear-Host
$host.UI.RawUI.ForegroundColor = "Green"

$currentdrive = (Get-Location).Drive.Name
Write-Output " "
Write-Output "************************************************************************"
Write-Output "************** Collecting Logs Uses Disk Space *************************"
Write-Output "*** Calculating size of Gateway and Wildfly logs and free Disk Space ***"
Write-Output "*** Ensure the drive you are running from has enough free Disk Space ***"
Write-Output "*** for both the Gateway and Wildfly logs                            ***"
Write-Output "************************************************************************"

FREE-SPACE

#	Clear-Host

Write-Output " "
Write-Output "******************************************"  
Write-Output "******* HCP Gateway Log Working_Folder ***"
Write-Output "******************************************"
Write-Output " "

#	Clear-Host

$cname = "$env:COMPUTERNAME"
$timestamp = Get-Date -format "MM-dd-yyyy_hh-mm"
$basewfname ="Working_Folder\HCP_Gateway_Log_Collected_$cname`_$timestamp"
$dbasewfname ="Working_Folder\\HCP_Gateway_Log_Collected_$cname`_$timestamp"
#Write-Output "DEBUG basewfname is <$basewfname>, dbasewfname is <$dbasewfname>,cname is <$cname>, new param is <$timestamp`_$cname>"
Write-Output "********************************************"
Write-Output "***   Log Collection Date = $timestamp   ***"
Write-Output "********************************************"

do {
# Prompt user for option
	Write-Output " "
	Write-Output " Enter 1 to Collect HCP Gateway Logs "
	Write-Output " Enter 2 to Check Drive Free Space "
	Write-Output " Enter 3 to EXIT script"
	$a = Read-Host -Prompt "`n Enter your option "
	switch($a)
	{
		1{GW-LOGS}
		2{FREE-SPACE}
		3{Exit}
	}
} until ($a -eq 3)

