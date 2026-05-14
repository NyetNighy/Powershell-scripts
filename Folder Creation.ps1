# Location Where your folders are to be created

Set-Location "C:\Users\phillip nye\Documents" 

# Import CSV file from location
 
$Folders = Import-Csv "C:\Users\phillip nye\Documents\St margarets.csv" 

# Create Folders from CSv ensure your have a heading of Name in your CSV file
 
ForEach ($Folder in $Folders) { 
 
New-Item $Folder.Name -type directory 
}  