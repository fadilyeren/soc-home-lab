# Home Lab: PowerShell Script Block Logging'i açar (Olay 4104).
#
# Nerede çalışır : Windows VM içinde, YÖNETİCİ olarak açılmış PowerShell'de.
# Nasıl çalışır  : powershell -ExecutionPolicy Bypass -File \\VBOXSVR\homelab\windows-vm\powershell-kaydi.ps1
# Ne yapar       : 1) Script Block Logging ilkesini kayıt defterinde açar
#                     (Grup İlkesi'ndeki "Turn on PowerShell Script Block Logging" ayarının karşılığı)
#                  2) Yeni bir PowerShell sürecinde zararsız, işaretli bir test komutu çalıştırır
#                     (ilke yalnızca yeni başlayan PowerShell süreçlerinde geçerlidir)
#                  3) Test komutunun Olay 4104 olarak kaydedildiğini kontrol eder
# Geri almak için: Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -Value 0
# Tekrar çalıştırmak güvenlidir.
#
# Not: Bu ayar Windows PowerShell 5.1 içindir. PowerShell 7 ayrı bir kayıt defteri yolu
# ve ayrı bir günlük (PowerShellCore/Operational) kullanır.

$ErrorActionPreference = 'Stop'

# 1) İlkeyi aç
$yol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
New-Item -Path $yol -Force | Out-Null
Set-ItemProperty -Path $yol -Name EnableScriptBlockLogging -Value 1 -Type DWord
$deger = (Get-ItemProperty -Path $yol).EnableScriptBlockLogging
Write-Host "1/3 Script Block Logging acildi (EnableScriptBlockLogging = $deger)."

# 2) İşaretli test komutu (yalnızca ekrana yazı yazar)
$isaret = 'SOCAGENT-4104-TEST-' + (Get-Date -Format 'yyyyMMddHHmmss')
$baslangic = (Get-Date).AddSeconds(-5)
powershell.exe -NoProfile -Command "Write-Output '$isaret'" | Out-Null
Write-Host "2/3 Test komutu calistirildi. Isaret: $isaret"
Start-Sleep -Seconds 3

# 3) Test komutu Olay 4104 olarak kaydedildi mi?
$olay = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    Id        = 4104
    StartTime = $baslangic
} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match $isaret } | Select-Object -First 1

if ($olay) {
    Write-Host "3/3 Test olayi kaydedildi: Olay $($olay.Id), $($olay.TimeCreated)."
    Write-Host "    Splunk'ta aramak icin: index=wineventlog earliest=-15m `"$isaret`""
} else {
    Write-Host "3/3 UYARI: Test olayi bulunamadi. Birkac saniye sonra betigi tekrar calistir."
}
