$userToLogoff = 'someuser'

Get-RDUserSession -ConnectionBroker v46.pw.salova -CollectionName 1C-DPC |
Sort-Object UserName |
Where-Object UserName -eq $userToLogoff |
Select-Object -First 1 |
ForEach-Object {
    Invoke-RDUserLogoff -HostServer $_.HostServer -UnifiedSessionID $_.UnifiedSessionId -Force
}