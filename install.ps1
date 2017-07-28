Set-PowerCLIConfiguration -InvalidCertificateAction:"ignore" -Confirm:$false

Connect-VIServer -Server 192.168.1.11 -Protocol https -User root -Password homelabnyc

Import-VApp -Source image.ova -VMHost localhost.localdomain
