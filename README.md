# psLdapModify

###Powershell Script to utilize System.DirectoryServices.Protocols to add/change/delete attributes of an LDAP object
###Fed by a csv file (sperated with ";")
###Sends a summary by email afer completion

##Example call
`.\Modify.ps1 -Datafile .\inputfile.csv -Stage Test -ProcessMultiHit false -DoneRecieptient reciepient@example.com`

**-Stage**
  Specify Test/Prelive/Live
  Refers to the config.ini section [Stages]
**-ProcessMultiHit**
**-DoneRecieptient**





