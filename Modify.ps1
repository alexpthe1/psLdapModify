Param(
    [Parameter(Position=0,Mandatory=$true)]
    [string]$Datafile,
    [Parameter(Position=1,Mandatory=$true)]
    [ValidateSet('Live','Prelive','Test')]
    [System.String]$Stage,
    [Parameter(Position=2,Mandatory=$false)]
    [System.Boolean]$ProcessMultiHit=$false,
    [Parameter(Position=2,Mandatory=$false)]
    [System.String]$DoneRecieptient=$null
    )


. .\readINI.ps1
. .\WriteLog.ps1
$Starttime=get-date
$Timestamp=$Starttime.ToString("yyyyMMdd_HH_mm_ss")

function MakeModRequest{
 param (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]$LDAPServer,
        [Parameter(Mandatory)]
        [string]$DN,
        [Parameter(Mandatory)]
        [string]$Attribute,
        [string]$Value
    )


    if($Value)
    {

        $ModReq = [System.DirectoryServices.Protocols.ModifyRequest]::new()

        $ModReq.DistinguishedName = $dn
        Write-Log -Severity Information -Message ("Mod of: " + $dn)
        Write-Log -Severity Information -Message ("Writing: "+ $Attribute+"="+$Value)
        $replace = @{
        Name = $Attribute
        Operation = 'Replace'
        } -as [System.DirectoryServices.Protocols.DirectoryAttributeModification]
        $replace.Add($Value)

        $ModReq.Modifications.Add($replace) | Out-Null


        $result =$LDAPServer.SendRequest($ModReq)
        return $result
    }
    else
    {
        $ModReq = [System.DirectoryServices.Protocols.ModifyRequest]::new()
        $ModReq.DistinguishedName = $dn
        Write-Log -Severity Information -Message ("Mod of: " + $dn)
        Write-Log -Severity Information -Message ("Deleting: "+ $Attribute)

        $delete = @{
        Name = $Attribute
        Operation = 'Delete'
        } -as [System.DirectoryServices.Protocols.DirectoryAttributeModification]

        $ModReq.Modifications.Add($delete) | Out-Null


        $result =$LDAPServer.SendRequest($ModReq)
        return $result

    }

}



$invocation=$MyInvocation
Write-Log -Severity Information -Message ("START: " + $invocation.Line)
Write-Log -Severity Information -Message ("Reading Config")

$LDAPUser =    GetConfValue -Header "General" -Key "LDAPUser"
$LDAPPass =    GetConfValue -Header "General" -Key "LDAPPass"
$LDAPSearchDN= GetConfValue -Header "General" -Key "LDAPSearchDN"
$LDAPSizeLimit=GetConfValue -Header "General" -Key "LDAPaSizeLimit"
$LDAPPageSize= GetConfValue -Header "General" -Key "LDAPPageSize"

$TestServer=    GetConfValue -Header "Stages"  -Key "Test"
$PreliveServer= GetConfValue -Header "Stages"  -Key "Prelive"
$LiveSerever=   GetConfValue -Header "Stages"  -Key "Live"

$outputfile= "output"+$Timestamp+".csv"

"SearchAttr;SearchVal;WriteAttr;WriteVal;DistinguishedName;Result" | Out-File -FilePath $outputfile -Encoding utf8


if(Test-Path -Path $Datafile)
{
    Write-Log -Severity Information -Message ("Reading `"" + $Datafile + "`"")
    $data = Import-Csv -Path $Datafile -Delimiter ";" -Encoding UTF8
    $countrows=($data | measure).Count
    Write-Log -Severity Information -Message ("Read " + $countrows + " rows")
}
else
{
    Write-Log -Severity Error -Message ("Inputfile `"" + $Datafile + "`" not found")
    exit 1
}


 switch($Stage)
{
    Live{
        $LDAPDirectoryService = $LiveSerever
    }
    Prelive{
        $LDAPDirectoryService = $PreliveServer
    }
    Test{
        $LDAPDirectoryService = $TestServer
    }

}

$null = [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.Protocols')
$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Net')
$LDAPServer = New-Object System.DirectoryServices.Protocols.LdapConnection $LDAPDirectoryService
$LDAPServer.AuthType = [System.DirectoryServices.Protocols.AuthType]::Basic
$LDAPServer.Timeout = New-Object system.TimeSpan 0,0,25,0,0
$LDAPServer.SessionOptions.ProtocolVersion = 3
$LDAPServer.SessionOptions.SecureSocketLayer =$true

$credentials = new-object "System.Net.NetworkCredential" -ArgumentList $LDAPUser,$LDAPPass

Try {
    $ErrorActionPreference = 'Stop'
    $LDAPServer.Bind($credentials)
    $ErrorActionPreference = 'Continue'
}
Catch
{
    
    Write-Log -Severity Error -Message ("Error binding to ldap  - $($_.Exception.Message)")
    Throw "Error binding to ldap  - $($_.Exception.Message)"
}


$i=0
foreach($row in $data)
{
    $i++
    try{
   

        $Scope = [System.DirectoryServices.Protocols.SearchScope]::Subtree
        #$AttributeList = ,"+" #operational attributes
        $AttributeList = ,"" #no attributes

        $LDAPFilter ="(" + $row.SearchAttr + "=" + $row.SearchVal + ")"
        $SearchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $LDAPSearchDN,$LDAPFilter,$Scope,$AttributeList

        if($ProcessMultiHit)
        {
            $searchRequest.SizeLimit = $LDAPSizeLimit
        }
        else
        {
            $searchRequest.SizeLimit = 3000
        }
 


        $SearchRequest.Attributes.Add("dn") | Out-Null

 
 
        $pageResultControl = New-Object System.DirectoryServices.Protocols.PageResultRequestControl(10)
        [Void]$searchRequest.Controls.Add($pageResultControl)



        $response = @()
        $j=0
        Write-Log -Severity Information -Message ("Search: " + $SearchRequest.Filter + " in: " +$SearchRequest.DistinguishedName)
        do
        {
            $j++

            $searchResponse = [System.DirectoryServices.Protocols.SearchResponse] $LDAPServer.SendRequest($searchRequest)
            $searchResponse.Controls | ? { $_ -is [System.DirectoryServices.Protocols.PageResultResponseControl] } | % {$pageResultControl.Cookie = ([System.DirectoryServices.Protocols.PageResultResponseControl]$_).Cookie}
  
            $response += $searchResponse.Entries
            if ($response.Count -ge $searchRequest.SizeLimit)
            {
                break
            }

        }
        while ($pageResultControl.Cookie.length -gt 0)



        $HitCount = ($response | measure).Count
        Write-Log -Severity Information -Message ("Recieved "+ $HitCount + " Objects from " + $j + " Pages")

        if($HitCount -ge 1)
        {

            if($ProcessMultiHit)
            {
                foreach($identity in $response)
                {
                   
                    $result = MakeModRequest -LDAPServer $LDAPServer -DN $identity.DistinguishedName -Attribute $row.WriteAttr -Value $row.WriteVal
                    Write-Log -Severity Information -Message ($result.ErrorMessage)
                    $row.SearchAttr + ";" + $row.SearchVal + ";" + $row.WriteAttr + ";" + $row.WriteVal + ";" + $identity.DistinguishedName + ";" + $result.ErrorMessage | Out-File -FilePath $outputfile -Encoding utf8 -Append


               

                }
            }
            else
            {
                  
                    $result = MakeModRequest -LDAPServer $LDAPServer -DN $response[0].DistinguishedName -Attribute $row.WriteAttr -Value $row.WriteVal
                    Write-Log -Severity Information -Message ($result.ErrorMessage)
                    $row.SearchAttr + ";" + $row.SearchVal + ";" + $row.WriteAttr + ";" + $row.WriteVal + ";" + $response[0].DistinguishedName + ";" + $result.ErrorMessage | Out-File -FilePath $outputfile -Encoding utf8 -Append

            }
        }
        else
        {
            $row.SearchAttr + ";" + $row.SearchVal + ";" + $row.WriteAttr + ";" + $row.WriteVal + ";" + "No results to process" + ";" + "No results to process" | Out-File -FilePath $outputfile -Encoding utf8 -Append
            Write-Log -Severity Warning -Message ("No results to process")
      
        }






    }
    catch
    {
         Write-Log -Severity Error -Message ("Error while Processing Line " + $i)
         Write-Log -Severity Error -Message ("Input Data: " + ($row | ConvertTo-Json -Compress).ToString())   
         Write-Log -Severity Error -Message ("Error: " + $_.Exception.Message)
         Write-Log -Severity Error -Message ("Stacktrace: " + $_.ScriptStackTrace)
    }

}



Write-Log -Severity Information -Message ("END")


if($DoneRecieptient)
{
$outputfragment=Import-Csv $outputfile -Delimiter ";"| ConvertTo-Html -Fragment 

$style=

$body=""
$body+= "<div><p>Dies ist eine Benachrichtigung über den beendeten Lauf folgendes Scripts:</p>"
$body+= "<ul>"
$body+= "<li><p>Startzeitpunkt: " + $Starttime + "</p></li>"
$body+= "<li><p>Aufruf: " + $invocation.Line + "</p></li>"
$body+= "<li><p>Aufrufender User: " + $env:UserName+"@"+$env:COMPUTERNAME + "</p></li>"
$body+= "<li><p>Laufzeit: " + [Math]::round(((Get-Date)-$Starttime).TotalMinutes,0) + " Minuten</p></li>"
$body+= "</ul>"
$body+= "</div>"+ $outputfragment


.\MailDoneNotification.ps1 -Body $body -Subject ("Done: "+$invocation.Line) -To $DoneRecieptient
}