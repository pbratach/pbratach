# Parse the Gateway file metadata and HCP jvm efinfo information from hcpgw-Generate-admin-jvm-efinfo-v4.ps1 script
$myscriptname = &{$myInvocation.ScriptName}
$logname=$($args[0])
$outfilename="$logname.csv"
$hashtypeline=Get-Content -Path $logname -TotalCount 1
$rest, $hashtypetext = $hashtypeline.split(":")
$hashtype=$hashtypetext.trim()
Write-Host "DEBUG HASH LINE: <$hashtypeline>, TYPE: <$hashtype>"
switch ( $hashtype ) {
	"NONE" {
			$hashfind = "hash-none"
			break
	}
	"MD5" {
			$hashfind = "md5HashSignature"
			break
	}
	"SHA-1" {
			$hashfind = "SHA-1"
			break
	}
	"SHA-256" {
			$hashfind = "SHA-256"
			break
	}
}
$inputFile= Get-Content $logname
foreach($i in Get-Content $logname) {
 if ($i.Contains("HCPGatewayFileInformation: ")) 	{
		Write-Host "Processing file $i"
		if ($i.length -lt 28) {
			Write-Output "No Gateway file metadata"
			continue
		}
		# Parse out filename
		$efinfoDate, $efinfoDelete = $NULL
		$fname, $fsid, $insertDate, $size, $visible, $location, $hash, $uuid, $versionplus, $rest = $i.split("`t")
		$version,$rest = $versionplus.split(" ")
#		Write-Host "DEBUG GW FILE INFO: $fname, $fsid, $insertDate, $size, $visible, $location, $hash, $uuid, $version" 
#		$efinfoData = ($inputFile | select-string "$uuid, v: " -Context 0,165 ).ToString()
#		$efinfoData = ($inputFile | select-string "$uuid, v: " -Context 0,159 ).ToString()
		$efinfoData = ($inputFile | select-string "$uuid, v: " -Context 0,75 )
#		Write-Host "DEBUG EFINFODATA: $efinfoData"
		foreach ($j in $($efinfoData -split "`r`n")) {
#			Write-Host "DEBUGL: $j"
#			if ($j.Contains("formattedChangeTime") ) { 
#				Write-Host "DEBUG: formattedChangeTime: $j" 
#				$efinfoDate = $j.split("'")[3]
#			}
			if ($j.Contains("isDeleteOperation") ) { 
#				Write-Host "DEBUG: isDeleteOperation: $j" 
				$ed1 = $j.split(":")[-1]
				$efinfoDelete = $ed1.split(",")[0]
			}
			if ($j.Contains("size") ) { 
#				Write-Host "DEBUG: object size: $j" 
				$ed1 = $j.split(":")[-1]
				$efinfoSize = $ed1.split(",")[0]
			}
			if ($j.Contains($hashfind) ) { 
#				Write-Host "DEBUG: object hash: $j" 
				$ed1 = $j.split(":")[-1]
				$efinfohashSignature = $ed1.split(",")[0].split("'")[1]
			}
		}

	#	>$efinfo
		Write-Output "$fname`t$fsid`t$insertDate`t$visible`t$location`t$uuid`t$version`t$size`t$hash`t$efinfoSize`t$efinfohashSignature`t$efinfoDelete" | Out-File "$outfilename" -Append
	}
}