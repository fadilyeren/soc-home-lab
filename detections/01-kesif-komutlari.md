# Keşif komutları: kısa sürede çok sayıda farklı keşif aracı

**Durum:** ayıklanmış (uyarıya çevrilmedi)

## Ne tespit eder

Aynı makinede 3 dakika içinde en az 3 farklı yerel keşif aracının (`whoami`, `net`, `systeminfo`, `cmdkey`) çalıştırılmasını tespit eder.

## ATT&CK eşlemesi

- T1033 System Owner/User Discovery
- T1087.001 Account Discovery: Local Account
- T1082 System Information Discovery

## Gerekli veri kaynakları

- Index `sysmon`, Sysmon `EventID=1` (süreç oluşturma)
- Kullanılan alanlar: `Image`, `host`, `_time`

## Saldırı adımları

Windows VM'de yönetici PowerShell, Atomic Red Team:

```powershell
Invoke-AtomicTest T1033 -TestNumbers 7
Invoke-AtomicTest T1087.001 -TestNumbers 8
Invoke-AtomicTest T1082 -TestNumbers 1
Invoke-AtomicTest T1033 -TestNumbers 7 -Cleanup
```

Bu testler `net`, `cmdkey`, `systeminfo` ve `reg` çalıştırır; hiçbiri `whoami` çalıştırmaz. T1033-7 içindeki `query user`, Windows 10 Home'da `query.exe` olmadığı için hata verir (exit code 1). Testin `net users` kısmı yine de çalışır.

## SPL

```
index=sysmon EventID=1 Image IN (*\\whoami.exe, *\\net.exe, *\\systeminfo.exe, *\\cmdkey.exe)
| sort _time
| streamstats time_window=3m dc(Image) as komutlar by host
| table _time, host, Image, komutlar
| where komutlar > 2
```

- `dc(Image)`: Keşifte saldırganı ayıran şey komut sayısı değil, çeşitliliktir. Aynı aracı tekrar tekrar çağıran bir betik `count` ile alarm verir, `dc` ile vermez.
- `streamstats time_window=3m`: Kayan pencere. İlk sürümde `bin _time span=10m` kullanıldı; sabit kutular iki ayrı çalıştırmayı birleştirdi, birini de ikiye böldü.
- `sort _time`: Splunk sonuçları yeniden eskiye getirir. Sıralama yapılmazsa pencere geriye değil ileriye bakar.
- `by host`: Her makine ayrı sayılır. Farklı makinelerdeki zararsız tekil komutlar birleşip alarm üretmez.
- `> 2`: En az 3 farklı araç. `> 1` her iki komutluk yönetici kullanımında (ör. `whoami` ardından `net user`) alarm verirdi.

## Ayıklama notları

- **Atomic Red Team'in kendi `whoami`'si:** ART her testten 1-2 saniye önce `whoami` çalıştırıyor. Kanıt: 7 `whoami` olayının üst süreci, test `cmd.exe`'lerinin üst süreciyle aynı PowerShell (`ParentProcessId` 7136 ve 4992). `whoami` gerçek saldırılarda sık kullanıldığı için listede bırakıldı. Tek başına çalışan ART `whoami`'si (cleanup, 12:27:53) `dc` eşiği sayesinde alarm üretmiyor.
- **Forwarder açılışı:** `splunk.exe`/`splunkd.exe` VM açılışında `cmd.exe` başlatıyor (2026-11-21 12:05:07'de 4 olay). `cmd.exe` listede olmadığı için bu kurala etkisi yok.
- **`net1.exe` hariç:** `net.exe` her çalıştığında `net1.exe`'yi de başlatır; ikisini birden saymak her komutu iki kez sayar.

## Bilinen sınırlamalar

- Saldırgan `net1.exe`'yi doğrudan çalıştırırsa `net.exe` hiç görünmez ve bu kural o komutu saymaz.
- 3 dakikadan daha yavaş yapılan keşif yakalanmaz.
- Lab'da gerçek yönetici aktivitesi yok; eşiğin gerçek ortamdaki yanlış alarm oranı ölçülmedi.
- `reg.exe` (T1082-1'in `reg query`'si) listede yok.

## Test kanıtı

Testler iki kez çalıştırıldı (2026-11-21, VM saati UTC+03:00):

| Çalıştırma | Saat | Kuralın ilk yakaladığı an |
|---|---|---|
| 1 | ~12:10:30 – 12:10:53 | 12:10:42.135 (`cmdkey`, 3 farklı araç) |
| 2 | 12:18:47 – 12:20:44 | 12:19:15.396 (`cmdkey`, 3 farklı araç) |

Sorgu zaman aralığı 2026-11-21 12:00:00 – 2026-11-22 13:56:57: 19 keşif olayından 10'u eşiği geçti, hepsi `windows10`. İki çalıştırma ayrı ayrı yakalandı.

## Analistin sonraki adımları

- Komutların üst sürecine bak (`ParentImage`, `ParentProcessId`): bunları hangi kabuk veya program başlattı?
- Aynı makinede, aynı kullanıcıyla yakın zamanda yapılan girişlere bak (Security 4624).
- Aynı zaman aralığında başka şüpheli etkinlik var mı: yeni hesap (4720), yönetici grubuna ekleme (4732), PowerShell betikleri (4104), ağ bağlantıları (Sysmon 3)?
