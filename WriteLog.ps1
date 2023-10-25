function Write-Log {
     [CmdletBinding()]
     param(
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         $Message,
 
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [ValidateSet('Information','Warning','Error')]
         [string]$Severity = 'Information'
     )
 

if($Severity -eq 'Error') 
{
$Message | Write-Host -ForegroundColor Red
}
if($Severity -eq 'Warning') 
{
$Message | Write-Host -ForegroundColor DarkYellow
}
     
    "["+(Get-Date -f g)+"]-["+$Severity+"]-["+$env:UserName+"@"+$env:COMPUTERNAME+"]: " + ($Message -join " # ") | Out-File -FilePath "LogFile.txt" -Append
 }