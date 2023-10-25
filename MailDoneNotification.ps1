Param(

    [string]$Subject,
    [string]$Body,
    [string]$To
)

. .\readINI.ps1
. .\WriteLog.ps1

$MailHeaderFile = GetConfValue -Header "Mail" -Key "HeaderFile"
$MailFooterFile = GetConfValue -Header "Mail" -Key "FooterFile"
$MailFrom =       GetConfValue -Header "Mail" -Key "From"
$MailServer =     GetConfValue -Header "Mail" -Key "Server"
$MailPass =       GetConfValue -Header "Mail" -Key "Password"

$header= gc .\$MailHeaderFile
$footer= gc .\$MailFooterFile
$BodyText = "$($header)$($body)$($footer)"

$userPassword = ConvertTo-SecureString -String $MailPass -AsPlainText -Force
$userCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $MailFrom, $userPassword

Send-MailMessage -From $MailFrom -To $To -Subject $Subject -SmtpServer $MailServer -Credential $userCredential -Encoding UTF8 -BodyAsHtml $BodyText 

