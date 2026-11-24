# Home Lab: soc_lab_forwarder uygulamasını Universal Forwarder'a kurar.
#
# Nerede çalışır : Windows VM içinde, YÖNETİCİ olarak açılmış PowerShell'de.
# Nasıl çalışır  : powershell -ExecutionPolicy Bypass -File \\VBOXSVR\homelab\universal-forwarder\kur.ps1
# Ne yapar       : 1) soc_lab_forwarder klasörünü forwarder'ın apps klasörüne kopyalar
#                  2) forwarder servis hesabına olay günlüklerini OKUMA izni verir
#                     ("Event Log Readers" grubu; en az yetki ilkesi, yönetici yapmaz)
#                  3) forwarder servisini yeniden başlatır (ayarlar ve izinler okunur)
#                  4) forwarder'ın her günlüğe abone olabildiğini kontrol eder
#                  5) host'taki Splunk'a (192.168.56.1:9997) ulaşılabiliyor mu test eder
# Tekrar çalıştırmak güvenlidir: zaten yapılmış adımları atlar.

$ErrorActionPreference = 'Stop'

$uf = 'C:\Program Files\SplunkUniversalForwarder'
if (-not (Test-Path "$uf\bin\splunk.exe")) {
    throw "Universal Forwarder bulunamadi: $uf. Once forwarder'i kur."
}

# 1) Uygulamayı kopyala
$kaynak = Join-Path $PSScriptRoot 'soc_lab_forwarder'
$hedef  = Join-Path $uf 'etc\apps\soc_lab_forwarder'
New-Item -ItemType Directory -Path $hedef -Force | Out-Null
Copy-Item -Path (Join-Path $kaynak '*') -Destination $hedef -Recurse -Force
Write-Host "1/5 Uygulama kopyalandi: $hedef"

# 2) Servis hesabına günlük okuma izni
#    Forwarder varsayılan olarak düşük yetkili "NT SERVICE\SplunkForwarder" hesabıyla çalışır.
#    Bu hesap Sysmon günlüğünü okuyamaz (errorCode=5, erişim engellendi).
#    "Event Log Readers" grubu (SID S-1-5-32-573) olay günlüklerini yalnızca okuma izni verir.
#    Grup SID ile bulunur; Windows'un dili ne olursa olsun çalışır.
$hesap = (Get-CimInstance Win32_Service -Filter "Name='SplunkForwarder'").StartName
$grup  = Get-LocalGroup -SID 'S-1-5-32-573'
if ($hesap -eq 'LocalSystem') {
    Write-Host "2/5 Servis LocalSystem ile calisiyor; ek izin gerekmiyor."
} else {
    try {
        Add-LocalGroupMember -Group $grup -Member $hesap -ErrorAction Stop
        Write-Host "2/5 '$hesap' hesabi '$($grup.Name)' grubuna eklendi."
    } catch [Microsoft.PowerShell.Commands.MemberExistsException] {
        Write-Host "2/5 '$hesap' zaten '$($grup.Name)' grubunda."
    }
}

# 3) Servisi yeniden başlat (yeni grup üyeliği ancak yeniden başlatınca geçerli olur)
$baslangic = Get-Date
Restart-Service -Name SplunkForwarder
Write-Host "3/5 SplunkForwarder servisi yeniden baslatildi. Gunlukler okunurken 30 sn bekleniyor..."
Start-Sleep -Seconds 30

# 4) Yeniden başlatmadan sonra abone olunamayan günlük var mı?
$log = Join-Path $uf 'var\log\splunk\splunkd.log'
$kultur = [System.Globalization.CultureInfo]::InvariantCulture
$hatalar = Get-Content -Path $log -Tail 2000 | Where-Object { $_ -match 'Could not subscribe' } | Where-Object {
    $zaman = [datetime]::MinValue
    $_.Length -ge 23 -and [datetime]::TryParseExact($_.Substring(0, 23), 'MM-dd-yyyy HH:mm:ss.fff', $kultur, 'None', [ref]$zaman) -and $zaman -ge $baslangic
}
if ($hatalar) {
    Write-Host "4/5 UYARI: Bazi gunluklere abone olunamadi:"
    $hatalar | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "4/5 Tum gunluklere abone olundu (yeni 'Could not subscribe' hatasi yok)."
}

# 5) Host'taki Splunk'a bağlantı testi
Write-Host "5/5 Host'taki Splunk'a baglanti testi (192.168.56.1:9997):"
Test-NetConnection -ComputerName 192.168.56.1 -Port 9997 -WarningAction SilentlyContinue |
    Select-Object ComputerName, RemotePort, TcpTestSucceeded | Format-Table -AutoSize
