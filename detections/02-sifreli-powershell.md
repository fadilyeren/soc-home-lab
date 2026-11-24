# Şifrelenmiş PowerShell komutu (-EncodedCommand)

**Durum:** ayıklanmış (uyarıya çevrilmedi)

## Ne tespit eder

`powershell.exe`'nin Base64 ile kodlanmış bir komutla (`-EncodedCommand` ve kısaltmaları) başlatılmasını tespit eder.

## ATT&CK eşlemesi

- T1059.001 Command and Scripting Interpreter: PowerShell
- T1027 Obfuscated Files or Information (komut Base64 ve metin parçalama ile gizlenmiş)

## Gerekli veri kaynakları

- Index `sysmon`, Sysmon `EventID=1` (süreç oluşturma); alanlar `Image`, `CommandLine`, `ParentImage`, `ParentProcessId`
- İnceleme için index `wineventlog`, PowerShell `EventID=4104` (Script Block Logging; lab'da açık), alan `ScriptBlockText`

## Saldırı adımları

Windows VM'de yönetici PowerShell, Atomic Red Team:

```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 17
```

Test, `cmd.exe /c powershell.exe -e <Base64>` çalıştırır. Çözülmüş içerik ekrana yalnızca "Hello, from PowerShell!" yazar. İlk seçilen T1059.001-15, PowerShell Gallery'den AtomicTestHarnesses modülünü indirmeyi gerektirdiği için 17 ile değiştirildi.

Tekrar testi, farklı bir yazılışla:

```powershell
powershell.exe -enc VwByAGkAdABlAC0ASABvAHMAdAAgACcAdABlAGsAcgBhAHIAIAB0AGUAcwB0AGkAJwA=
```

(Base64 = `Write-Host 'tekrar testi'`)

## SPL

```
index=sysmon EventID=1 Image=*\\powershell.exe CommandLine IN ("*-e *", "*-ec *", "*-en *", "*-enc *", "*-EncodedCommand *")
| table _time, Image, ParentImage, process_id, ParentProcessId, CommandLine
```

- `Image=*\\powershell.exe`: Yalnızca PowerShell'in kendi komut satırı. Testteki `cmd.exe /c powershell.exe -e ...` satırı dışarıda kalır, aynı saldırı iki kez sayılmaz.
- Parametreden sonraki boşluk: `-e` ile başlayan başka parametreler (`-ExecutionPolicy`, `-Embedding`) eşleşmez.
- Değerler çift tırnak içinde: Tırnaksız `*-e *` boşluktan bölünüyor ve tek başına kalan `*` her şeyle eşleşiyordu.

## Ayıklama notları

Son 7 günde (2026-11-15 15:00 – 2026-11-22 15:39) aynı veri üzerinde:

| Sürüm | Olay | Neden |
|---|---|---|
| `CommandLine=*-e* OR CommandLine=*/e*` | 203 | OneDrive `FileCoAuth.exe` (`svchost.exe` altında), `OneDriveSetup.exe` gibi her program ve `-e`/`/e` ile başlayan her parametre |
| Yalnızca `powershell.exe`, tırnaksız liste | 11 | Kullanıcının kendi PowerShell penceresi, `CompatTelRunner.exe` altında `-ExecutionPolicy Restricted` ile çalışan Windows telemetri PowerShell'leri |
| Son sürüm (tırnaklı liste) | 1 | Yalnızca test |

## Bilinen sınırlamalar

- `/e`, `/enc` gibi eğik çizgili yazılışlar listede yok.
- `-enco`, `-encod` gibi ara kısaltmalar listede yok.
- Parametreden sonra boşluk yerine sekme veya tırnak gelirse eşleşmez.
- Yalnızca `powershell.exe`; PowerShell 7 (`pwsh.exe`) ve `powershell_ise.exe` yok.

## Test kanıtı

| Test | Saat (2026-11-22, VM UTC+03:00) | Sonuç |
|---|---|---|
| T1059.001-17 (`-e`) | 14:15:41.685 | Yakalandı (PID 5956; Atomic çıktısındaki CLIXML `ProcessId` ile aynı) |
| Elle `-enc` | 15:40:55.382 | Yakalandı (PID 312) |

Süreç zinciri (test): `explorer.exe` → `powershell.exe` (kullanıcı penceresi) → `cmd.exe /c powershell.exe -e ...` → `powershell.exe -e ...`.

**4104 ile çözülmüş içerik:** PowerShell her gizleme katmanını ayrı bir betik bloğu olarak kaydetti:

| Saat | ScriptBlockText |
|---|---|
| 14:15:41.876 | `& (gcm ('ie{0}' -f 'x')) ("Wr"+"it"+"e-H"+"ost 'H"+"el"+"lo, fr"+"om P"+"ow"+"erS"+"h"+"ell!'")` |
| 14:15:41.947 | `Write-Host 'Hello, from PowerShell!'` |

Base64 elle çözülmeden asıl komut görüldü.

## Analistin sonraki adımları

- Şifreli PowerShell'i hangi program başlatmış (`ParentImage`)? Office, tarayıcı veya `wmiprvse.exe` çok şüphelidir.
- Aynı süreç ve zaman için 4104'te `ScriptBlockText`'e bak: komut çözülmüş halde ne yapıyor?
- Komut ağ bağlantısı kurduysa Sysmon `EventID=3`, dosya bıraktıysa Sysmon `EventID=11` ile devam et.
