# Run / RunOnce kayıt defteri anahtarına değer yazılması

**Durum:** ayıklanmış (uyarıya çevrilmedi)

## Ne tespit eder

`...\CurrentVersion\Run`, `RunOnce` ve `RunOnceEx` anahtarlarına yeni bir değer yazılmasını tespit eder. Windows bu anahtarlardaki programları oturum açılışında veya bir sonraki açılışta otomatik çalıştırır.

## ATT&CK eşlemesi

- T1547.001 Boot or Logon Autostart Execution: Registry Run Keys / Startup Folder

## Gerekli veri kaynakları

- Index `sysmon`, Sysmon `EventID=13` (kayıt defterine değer yazıldı)
- Alanlar: `TargetObject` (anahtar ve değer yolu), `Details` (yazılan veri), `Image` (yazan program)
- SwiftOnSecurity sysmon-config Run anahtarlarını kaydediyor; ek ayar gerekmedi.

## Saldırı adımları

Windows VM'de yönetici PowerShell, Atomic Red Team:

```powershell
Invoke-AtomicTest T1547.001 -TestNumbers 1
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
Invoke-AtomicTest T1547.001 -TestNumbers 1 -Cleanup

Invoke-AtomicTest T1547.001 -TestNumbers 2
Invoke-AtomicTest T1547.001 -TestNumbers 2 -Cleanup
```

- T1547.001-1: `HKCU\...\Run` altına `Atomic Red Team` = `C:\Path\AtomicRedTeam.exe` yazar (var olmayan dosya, hiçbir şey çalışmaz).
- T1547.001-2: `HKLM\...\RunOnceEx\0001\Depend` altına `C:\Path\AtomicRedTeam.dll` yazar.

## SPL

```
index=sysmon EventID=13 TargetObject=*\\CurrentVersion\\Run* (Image!="*\\Program Files (x86)\\Microsoft\\*\\Installer\\setup.exe")
| table _time, TargetObject, Image, Details
```

- `TargetObject=*\\CurrentVersion\\Run*`: Run, RunOnce ve RunOnceEx; HKCU, HKLM ve HKU altında. Yalnızca `\\Run\\*` yazmak 7 günde 1 olaya iniyordu ama RunOnce'ı tamamen kör bırakıyordu.
- `Image!=...`: Edge ve Copilot yükleyicileri ayıklandı. Tek kalıp kullanıldı. İki ayrı `!=`'yi `AND` ile bağlamak "ikisinden biri uyarsa dışarıda bırak" anlamına geliyor ve ayıklamayı istemeden genişletiyordu.

## Ayıklama notları

Son 7 günde (2026-11-15 18:00 – 2026-11-22 18:28):

| Sürüm | Olay |
|---|---|
| Tüm Sysmon 13 | 2.114 (çoğu OneDrive kabuk eklentisi kayıtları) |
| `\\CurrentVersion\\Run*` | 11 |
| + Edge/Copilot yükleyicisi ayıklandı | 9 (test öncesi) → 10 (RunOnceEx testinden sonra) |

- **Ayıklandı:** `C:\Program Files (x86)\Microsoft\Edge\...\Installer\setup.exe` ve `...\Copilot\...\Installer\setup.exe`, `HKLM\...\RunOnce\msedge_cleanup_{GUID}` yazıyor. Bu klasöre yazmak yönetici yetkisi ister, adı taklit etmek zor.
- **Bilerek bırakıldı:** `C:\Users\...\AppData\Local\Microsoft\OneDrive\...\OneDriveSetup.exe`, güncellemelerde `RunOnce\Uninstall <sürüm>` ve `RunOnce\Delete Cached Standalone Update Binary` yazıyor (7 günde 8 olay; her değer aynı milisaniyede iki kez kaydedilmiş). `AppData`'ya kullanıcı, dolayısıyla saldırgan da yazabilir. Bu ada göre ayıklamak saldırgana saklanma yeri verirdi.
- İlke: Yanlış alarm yalnızca saldırganın taklit edemeyeceği bir özelliğe göre ayıklanır.

## Bilinen sınırlamalar

- Sysmon 13 yalnızca yazma anını kaydeder. Sysmon kurulmadan önce yerleştirilmiş kalıcılık görünmez. Örneğin Run'daki meşru `OneDrive` değeri 7 günde hiç olay üretmedi.
- Başlangıç klasörü, zamanlanmış görev, hizmet, WMI gibi diğer kalıcılık yöntemleri kapsanmıyor.
- Ayıklanan yolun başında joker var. Yalnızca `C:\Program Files (x86)\...` ile başlayacak şekilde sıkılaştırılabilir.

## Test kanıtı

| Test | Saat (2026-11-22, VM saati) | Anahtar | Sonuç |
|---|---|---|---|
| T1547.001-1 | 17:40 | `HKCU\...\Run\Atomic Red Team` | Yakalandı |
| T1547.001-2 | 18:24 | `HKLM\...\RunOnceEx\0001\Depend\1` | Yakalandı |

Not: Bu testler sırasında VM saati ana bilgisayardan yaklaşık 10 dakika gerideydi; saatler VM saatidir (Splunk `_time` ile aynı).

## Analistin sonraki adımları

- `Details`: değer hangi dosyayı gösteriyor? Konumu olağan mı (`AppData`, `Temp`, `ProgramData` şüphelidir)? Dosya var mı, imzalı mı?
- `Image`: değeri hangi program yazdı? Onu kim başlattı (Sysmon 1, `ParentImage`)?
- Değerin gösterdiği dosya ne zaman oluşturuldu (Sysmon 11)?
- Kullanıcı bir sonraki oturum açışında bu program çalıştı mı (Sysmon 1)?
