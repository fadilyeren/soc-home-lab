# Universal Forwarder (Windows VM)

Windows 10 kurban VM'inde çalışan Splunk Universal Forwarder'ın ayarları. Forwarder, VM'deki Windows olay loglarını ve Sysmon'u lab ağı üzerinden host'taki Splunk Enterprise'a gönderir.

```text
Windows 10 VM (192.168.56.x)                Host (192.168.56.1)
Universal Forwarder  ── TCP 9997 ──▶        Splunk Enterprise
  soc_lab_forwarder                           index: wineventlog, sysmon
```

## Dosyalar

| Dosya | Görevi |
|---|---|
| `soc_lab_forwarder/default/inputs.conf` | Hangi Windows günlüklerinin toplanacağı ve hangi index'e gideceği |
| `soc_lab_forwarder/default/outputs.conf` | Logların gönderileceği adres (`192.168.56.1:9997`) |
| `soc_lab_forwarder/default/app.conf` | Uygulamanın adı ve sürümü |
| `kur.ps1` | Uygulamayı VM'deki forwarder'a kopyalar, servis hesabına günlük okuma izni verir, servisi yeniden başlatır ve sonucu kontrol eder |

## Servis hesabı ve izinler

Universal Forwarder varsayılan olarak düşük yetkili `NT SERVICE\SplunkForwarder` hesabıyla çalışır. Bu hesap Sysmon günlüğünü okuyamaz; forwarder günlüğünde `errorCode=5` (erişim engellendi) hatası görülür.

`kur.ps1` bu hesabı Windows'un **Event Log Readers** grubuna ekler. Bu grup olay günlüklerini yalnızca okuma izni verir. Forwarder'ı Local System (tam yetki) ile çalıştırmak da sorunu çözerdi, ama ihtiyaç duyduğundan fazla yetki verirdi (en az yetki ilkesi).

## Toplanan loglar

| Günlük | Index | Örnek olaylar |
|---|---|---|
| Security | `wineventlog` | 4624/4625 oturum açma, 4720 hesap oluşturma |
| System | `wineventlog` | 7045 yeni servis kurulumu |
| Application | `wineventlog` | Uygulama hataları |
| PowerShell/Operational | `wineventlog` | 4104 script block (ayrıca açılması gerekir) |
| Windows Defender/Operational | `wineventlog` | Defender tespitleri |
| Sysmon/Operational | `sysmon` | 1 süreç oluşturma, 3 ağ bağlantısı, 11 dosya oluşturma |

## Gürültü azaltma (tuning)

**Sorun:** Forwarder, kullanmadığımız Windows girdi türlerinin yardımcı programlarını (`splunk-admon`, `splunk-regmon`, `splunk-netmon`, `splunk-MonitorNoHandle`, `splunk-powershell`) tanımlı bir girdi olmasa bile dakikada bir başlatıyordu. Programlar yapacak iş bulamayıp kapanıyor, Sysmon ise her başlatmayı kaydediyordu.

**Nasıl bulundu:**
1. Sysmon olaylarını programa göre saydık: süreç başlatma olaylarının %82'si forwarder'dan geliyordu.
2. `btool` ile forwarder'da bu yardımcılar için tanımlı girdi olmadığını gördük.
3. Sysmon'daki komut satırı ve üst süreç bilgisiyle hepsinin `splunkd.exe` tarafından, parametresiz ve dakikada bir başlatıldığını doğruladık.

**Çözüm:** `inputs.conf` içinde bu girdi türleri `disabled = 1` ve `interval = -1` ile kapatıldı. Sorun Sysmon'da gizlenmedi, kaynağında kesildi; Sysmon yapılandırmasında kör nokta açılmadı.

**Sonuç (2026-11-07):**

| | Önce | Sonra |
|---|---|---|
| Forwarder yardımcılarının başlatılması | dakikada 6 | 0 |
| Sysmon olayları (10 dakikada) | yalnızca olay 1 için ~80 | toplam 7 |

Pozitif kontrol: VM'de açılan Not Defteri Sysmon olay 1 olarak Splunk'ta görüldü; veri akışı bozulmadı.

## Kurulum

Ön koşullar (host):
1. Splunk'ta alıcı port 9997 açık (Settings > Forwarding and receiving).
2. Host güvenlik duvarında `192.168.56.0/24` ağından 9997'ye izin veren kural var.
3. Splunk'ta `wineventlog` ve `sysmon` index'leri oluşturulmuş (Settings > Indexes).

VM'de:
1. Splunk Universal Forwarder'ı kur. Sürümü host'taki Splunk'la aynı ya da daha eski olmalı. Kurulumda alıcı sunucu (receiving indexer) ve deployment server alanlarını boş bırak; adresi bu uygulama veriyor.
2. Yönetici PowerShell'de çalıştır (lab klasörü VM'e salt okunur paylaşım olarak bağlı):

   ```powershell
   powershell -ExecutionPolicy Bypass -File \\VBOXSVR\homelab\universal-forwarder\kur.ps1
   ```

3. Host'taki Splunk'ta kontrol et:

   ```spl
   index=wineventlog OR index=sysmon | stats count by index, source
   ```
