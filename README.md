# psLdapModify

Powershell Script to utilize System.DirectoryServices.Protocols to add/change/delete attributes of an LDAP object  
Fed by a csv file (sperated with ";")  
Sends a summary by email afer completion  

## Example call
`.\Modify.ps1 -Datafile .\inputfile.csv -Stage Test -ProcessMultiHit false -DoneRecieptient reciepient@example.com`

## Parameters  

* **-Datafile**  
  Specify the file which defines the search filters and the modify requests

* **-Stage**  
  Specify Test/Prelive/Live  
  Refers to the config.ini section "Stages"  
  
* **[-ProcessMultiHit]**  
  True / False  
  True = all search results will be modified  
  False = only the first result will be modified
  
* **[-DoneRecieptient]**  
  Recipient of the summary of results



## Datafile  
Following columns need to be defined:  
  
* SearchAttr  
The attribute used for searching the object  
* SearchVal  
The value of the SearchAttr for searching,  
will be used to build the ldapfilter according (SearchAttr=SearchVal)  
* WriteAttr  
The attribute tht have to be updated, deleted or added  
* WriteVal  
The value that have to be added or upated  
leave blank for deletion of the attribute
