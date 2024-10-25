<#
  
.EXAMPLE
  Traversal-fromFolders-2 101 E:\SAM\Archive101

#>
   

param (
 [int]$id ,
 [string]$path
)

# change this to 0 if don't want to log folder, default 1 means will log folder
$logFolder = 1

$source = @"
 using System;
 using System.Runtime.InteropServices;
 using System.ComponentModel;
 using System.IO;

 namespace Win32
 {
    
    public class Disk 
    {
	
    [DllImport("kernel32.dll")]
    static extern uint GetCompressedFileSizeW(
        [In, MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
        [Out, MarshalAs(UnmanagedType.U4)] out uint lpFileSizeHigh);	
        
    public static ulong GetSizeOnDisk(string filename)
    {
      uint HighOrderSize;
      uint LowOrderSize;
      ulong size;

      FileInfo file = new FileInfo(filename);
      LowOrderSize = GetCompressedFileSizeW(file.FullName, out HighOrderSize);

      if (HighOrderSize == 0 && LowOrderSize == 0xffffffff)
      {
	    throw new Win32Exception(Marshal.GetLastWin32Error());
      }
      else 
      { 
	    size = ((ulong)HighOrderSize << 32) + LowOrderSize;
	    return size;
      }
    }
  }
}

"@

Add-Type -TypeDefinition $source
$dllArchive = "$PSScriptRoot\ArchiveMgr.dll"
[void][system.reflection.Assembly]::LoadFrom($dllArchive)

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
    elseif ($key -like "database.ip" ) {
	   $dbip = $value
    }           
}


#Write-Output $dbProgram
# db connection info
$user = "root"
$pass = $dbRootPass
$database = $dbName
$MySQLHost = $dbip

function Get-DB-Auto-Increment
{
    <#
	$fs_table = "$id" + "_fs"
	$Sql.CommandText = "SELECT auto_increment FROM information_schema.tables where table_schema='$database' and table_name='$fs_table'"
	$myreader = $Sql.ExecuteReader()
	if($myreader.Read()){ $Num = $myreader.GetInt32(0) }
	$myreader.Close()
    #>
    $fs_table = "$id" + "_fs"
    $sql = "SELECT auto_increment FROM information_schema.tables where table_schema='$database' and table_name='$fs_table'"
    $Num = "$sql" | & "$dbProgram" --user=$user --password=$pass -b -s --database=$database --ssl
    if(!$?){
        Write-Output 'Get-DB-Auto-Increment error'
        exit
    }
	return [int]$Num.trim()
}

function Get-DB-New-Add
{
    <#
    # since Mariadb 10.10, MySql.Data.dll not work any more, so, call python for db operation
    param($auto_incr)
	$fs_table = "$id" + "_fs"
	$Sql.CommandText = "SELECT count(fsid) FROM $fs_table where fsid>$auto_incr and type=0 and visible=1"
	$myreader = $Sql.ExecuteReader()
	if($myreader.Read()){ $Num_file = $myreader.GetInt32(0) }

	$myreader.Close()
	$Sql.CommandText = "SELECT count(fsid) FROM $fs_table where fsid>$auto_incr and type=1 and visible=1"
	$myreader = $Sql.ExecuteReader()
	if($myreader.Read()){ $Num_folder = $myreader.GetInt32(0) }
	$myreader.Close()
    #>
    $fs_table = "$id" + "_fs"
    $sql = "SELECT count(fsid) FROM $fs_table where fsid>=$auto_num and type=0 and visible=1"
    $Num_file = "$sql" | & "$dbProgram" --user=$user --password=$pass -b -s --database=$database --ssl
    if(!$?){
        Write-Output 'Get-DB-New-Add for file error'
        exit
    }
    # get new add folder
    $sql = "SELECT count(fsid) FROM $fs_table where fsid>=$auto_num and type=1 and visible=1"
    $Num_folder = "$sql" | & "$dbProgram" --user=$user --password=$pass -b -s --database=$database --ssl
    if(!$?){
        Write-Output 'Get-DB-New-Add for folder error'
        exit
    }
	return [int]$Num_file.trim(), [int]$Num_folder.trim()

}

function Set-Replication
{
	param([int]$rep_value)
	#$Sql.CommandText = "UPDATE archive SET replication=$rep_value WHERE id=$id"
    #$res = $Sql.ExecuteNonQuery()
    $sql = "UPDATE archive SET replication=$rep_value WHERE id=$id"
    $res = "$sql" | & "$dbProgram" --user=$user --password=$pass -b -s --database=$database --ssl
    if(!$?){
        Write-Output 'Set-Replication value=$rep_value error'
        exit
    }
}

function Restart-Archive
{
  write-output "restarting archive id=$id"
  $ret = [ArchiveMgr.Program]::StopArchive($id)
  Start-Sleep 3
  #$Sql.CommandText = "UPDATE archive_state SET enabled=1 WHERE archiveId=$id"
  #$res = $Sql.ExecuteNonQuery()

  $sql = "UPDATE archive_state SET enabled=1 WHERE archiveId=$id"
  $res = "$sql" | & "$dbProgram" --user=$user --password=$pass -b -s --database=$database --ssl

  $ret = [ArchiveMgr.Program]::StartArchive($id)
  #write-output $ret
  if ($ret){
    write-output "restart archive id=$id done"
    write-output "====================================================="
    Start-Sleep 3
  }else{
    write-output "restart archive id=$id failed"
    exit
  }
}

#
# main
# prompt message, check replication filed
$input=Read-Host "This script will alter the archive table in the MariaDB database to set the replication value used by the script and then it will stop and start share, please confirm that the share (archive id=$id) can be taken offline for a few minutes now and then again when the script completes: Y/N"
if ($input -eq "yes" -or $input -eq "Y" -or $input -eq "YES"){
	write-output "confirm continue, received: $input"
    write-output "====================================================="
	# set replication value in archive table
	Set-Replication 0
	# restart archive
	Restart-Archive

}else{
	write-output "Confirmation not received to take the share offline and start the script, received: $input"
	return
}

# get fs table fsid auto increment before processing files
$auto_num = Get-DB-Auto-Increment

$retFile = ".\CacheFiles-archive$id.txt"
# Remove the comment on the next line to delete any existing log file
#Remove-Item -Path $retFile -Force -ErrorAction Ignore

$s_time = Get-Date
write-output "Start Processing Files, start time: $s_time"
write-output "Start Processing Files, start time: $s_time" >> $retFile
write-output "Processing path: $path" >> $retFile
write-output "DB auto increment fsid: $auto_num"  >> $retFile

$counter = 0  # File counter
$dirCounter = 0  # Folder counter
$cc = 1  # print file counter
$basePath = ""
$offline_tag = "Archive, SparseFile, Offline"
# the 1st way to do, comment it if uses the 2nd way

Get-ChildItem $path  -Recurse * | Where-Object { ! $_.PSIsContainer} | Foreach-Object { 
    
    $fileName = $_.FullName
    $file_attr = $_.Attributes.ToString()
    #Write-Output $_.DirectoryName
    if ( $basePath -ne $_.DirectoryName ){
        $cc = 1
        $new_cc = 1
        $basePath = $_.DirectoryName
        $dirCounter=$dirCounter+1
        Write-Output "`nProcessing folder-$dirCounter : $basePath"
        if ($logFolder -eq 1){
            write-output "Processing folder-$dirCounter : $basePath" >> $retFile
        }
    }
    # offline file print . every 100, new add file print * every 100
    if ($file_attr -ne $offline_tag){
        $size = [Win32.Disk]::GetSizeOnDisk($_.FullName)
        if ($new_cc % 100 -eq 0){
		    Write-host("*") -NoNewline
	    }
        $new_cc = $new_cc+1
    }else{
        if ($cc % 100 -eq 0){
		    Write-host(".") -NoNewline
	    }
        $cc = $cc+1
    }
     $counter=$counter+1

}


# the 2nd way to do, comment it if use the 1st way
<#
 # processing file under base specified dir
 Write-host("Processing folder-$dirCounter : ") -NoNewline
 Write-Output $path
 Get-ChildItem $path | Where-Object { ! $_.PSIsContainer} | ForEach-Object{
    # Write-Output $_.FullName
    $file_attr = $_.Attributes.ToString()
    # offline file print . every 100, new add file print * every 100
    if ($file_attr -ne $offline_tag){
        $size = [Win32.Disk]::GetSizeOnDisk($_.FullName)
        if ($new_cc % 100 -eq 0){
		    Write-host("*") -NoNewline
	    }
        $new_cc = $new_cc+1
    }else{
        if ($cc % 100 -eq 0){
		    Write-host(".") -NoNewline
	    }
        $cc = $cc+1
    }
    $counter=$counter+1
}
$dirCounter=$dirCounter+1
Write-Output ""

# processing file under sub_folder under specified dir
Get-ChildItem $path -Recurse * | Where-Object { $_.PSIsContainer} | Foreach-Object {
     Write-host("Processing folder-$dirCounter : ") -NoNewline
     $dirCounter=$dirCounter+1
     $folderName = $_.FullName
     if ($logFolder -eq 1){
         write-output "Processing folder-$dirCounter : $folderName" >> $retFile
         write-output "====================================================="  >> $retFile
     }
     $cc = 1
     $new_cc = 1
     # Get-ChildItem $folderName -Attributes !Offline | Where-Object { ! $_.PSIsContainer} | ForEach-Object{
     Get-ChildItem $folderName | Where-Object { ! $_.PSIsContainer} | ForEach-Object{ 
        $file_attr = $_.Attributes.ToString()
        # offline file print . every 100, new add file print * every 100
        if ($file_attr -ne $offline_tag){
            $size = [Win32.Disk]::GetSizeOnDisk($_.FullName)
            if ($new_cc % 100 -eq 0){
		        Write-host("*") -NoNewline
	        }
            $new_cc = $new_cc+1
        }else{
            if ($cc % 100 -eq 0){
		        Write-host(".") -NoNewline
	        }
        }
        $cc = $cc+1
        $counter=$counter+1
     }
     Write-Output ""
}
#>

write-output ""

# get fsid
$aft_file, $aft_dir = Get-DB-New-Add
# write-output "DB new insert files: $aft_file, folder: $aft_dir"

$e_time = Get-Date
write-output "End Processing Files"
write-output "Total files processed: $counter files"
write-output "Total files added to database: $aft_file files."
write-output "Total folders added to database: $aft_dir folders."
write-output "End time: $e_time"
write-output "End Processing Files" >> $retFile
write-output "Total files processed: $counter files"  >> $retFile
write-output "Total files added to database: $aft_file files."  >> $retFile
write-output "Total folders added to database: $aft_dir folders."  >> $retFile
write-output "End time: $e_time"  >> $retFile
write-output "====================================================="
# set replication value in archive table
Set-Replication 1
# prompt to restart share
# prompt message, check replication filed
$input=Read-Host "The traversal is completed, now the share is required to restart, please confirm that the share (archive id=$id) can be taken offline for a few minutes: Y/N"
if ($input -eq "yes" -or $input -eq "Y" -or $input -eq "YES"){
	write-output "confirm continue, received: $input"
    write-output "====================================================="
	# restart archive
	Restart-Archive
}else{
	write-output "Confirmation not received to take the share offline, please manually stop and start this share (archive id=$id). received: $input"
    write-output "====================================================="
}
$total_time = $e_time - $s_time
write-output "Time used: $total_time"
write-output "Time used: $total_time" >> $retFile
write-output "=====================================================" >> $retFile
write-output "End"