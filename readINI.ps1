param (
   $inputfile
)

. .\WriteLog.ps1




function GetConfValue {
 param (
         [Parameter(Mandatory)]
         [string[]]$Header,
        [Parameter(Mandatory)]
        [string[]]$Key
    )
    

($resulttable| where {$_.Key -eq $Key -and $_.segment -eq $Header}).value



}


function GetHeaders{


$Exports = $resulttable.segment | select -Unique
$Exports
}



if(-not $inptfile)
{

    $inputfile = "config.ini"
}

$inifile = get-content $inputfile

$resulttable=@()
foreach ($line in $inifile) {
   #write-host "Processing $line"
   if ($line[0] -eq ";") {
      #write-host "Skip comment line"
   }

   elseif ($line[0] -eq "[") {
      $segment = $line.replace("[","").replace("]","")
      #write-host "Found new segment: $segment"
   }
   elseif ($line -like "*=*") {
      #write-host "Found Keyline"
      $split = $line -split "=",2
      $resulttable += New-Object PSObject -Property @{
         segment  = $segment
         
         Key = $split[0]
         value    = $split[1]
         }
      }
      else {
         #write-host "Skip line"
      }
}
#$resulttable


