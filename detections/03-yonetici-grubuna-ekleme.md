# Yerel Administrators grubuna üye ekleme

**Durum:** ayıklanmış (uyarıya çevrilmedi)

## Ne tespit eder

Bir hesabın yerel Administrators grubuna eklenmesini, grubun dilden bağımsız SID'i (`S-1-5-32-544`) üzerinden tespit eder.

## ATT&CK eşlemesi

- T1098 Account Manipulation (yönetici grubuna ekleme)
- T1136.001 Create Account: Local Account (test senaryosunda ekleme yeni açılan hesapla yapıldı)

## Gerekli veri kaynakları

- Index `wineventlog`, Windows Security günlüğü
- `EventID=4732`: güvenlik etkin yerel gruba üye eklendi; alanlar `TargetSid` (grup), `src_user` (işlemi yapan), `MemberSid` (eklenen hesap)
- İnceleme için `EventID=4720`: hesap oluşturuldu; alanlar `user`, `TargetSid` (yeni hesabın SID'i)
- Lab'da bu olaylar için denetim ayarı doğrulandı (2026-11-11), ek ayar gerekmedi.

## Saldırı adımları

Windows VM'de yönetici PowerShell, Atomic Red Team:

```powershell
Invoke-AtomicTest T1136.001 -TestNumbers 8 -ShowDetailsBrief
Invoke-AtomicTest T1136.001 -TestNumbers 8
net localgroup administrators
Invoke-AtomicTest T1136.001 -TestNumbers 8 -Cleanup
```

Test, `cmd.exe` ile `net user /add "T1136.001_Admin" ...` ve `net localgroup administrators "T1136.001_Admin" /add` çalıştırır; cleanup hesabı siler. İlk seçilen T1136.001-4 + T1098-1 ikilisi değiştirildi, çünkü T1098-1 kullanıcıyı gruba eklemiyor, yerleşik Administrator hesabının adını değiştiriyordu.

## SPL

```
index=wineventlog EventID=4732 TargetSid=S-1-5-32-544
| table _time, EventID, src_user, user, Group_Name, TargetSid
```

- **Neden Sysmon değil:** Sysmon `net.exe`'nin çalıştığını görür. Hesap PowerShell (`Add-LocalGroupMember`), API veya uzaktan eklenirse `net.exe` hiç çalışmaz. 4732'yi ise Windows, ekleme hangi yolla yapılırsa yapılsın yazar. "Nasıl yapıldı?" sorusunun cevabı Sysmon'da, "Ne oldu?" sorusunun cevabı Security günlüğünde.
- **Neden grup adı değil SID:** Grup adı dile göre değişir (Türkçe Windows'ta "Yöneticiler"). `S-1-5-32-544` her Windows'ta aynıdır.
- **Neden tam SID:** İlk sürümdeki `TargetSid=*-544` da çalıştı, ama baştaki joker gereksiz tarama yaptırır.

## Ayıklama notları

- **Users grubuna otomatik ekleme:** Windows her yeni yerel hesabı `Users` grubuna (`S-1-5-32-545`) ekler ve bunun için de bir 4732 yazar. Tüm 4732'lerde alarm vermek her hesap açılışında yanlış alarm üretirdi. Kural yalnızca Administrators SID'ine bakar.
- Son 7 günde (2026-11-15 16:00 – 2026-11-22 16:07) yanlış alarm görülmedi.

## Bilinen sınırlamalar

- Yalnızca yerel Administrators. Remote Desktop Users, Backup Operators gibi diğer ayrıcalıklı gruplar ve etki alanı grupları (4728, 4756) kapsanmıyor.
- 4732'de eklenen üye adla değil SID ile (`MemberSid`) yazılıyor; tabloda `user` boş. Hesabın adını görmek için 4720'deki `TargetSid` ile eşleştirmek gerekiyor.
- Meşru yönetici atamaları da alarm verir; gerçek ortamda değişiklik kaydıyla karşılaştırılmalı.

## Test kanıtı

| Test | Saat (VM UTC+03:00) | Sonuç |
|---|---|---|
| Elle pozitif kontrol (`test-pozitif` hesabı) | 2026-11-20 15:02:09.677 | Yakalandı |
| T1136.001-8 | 2026-11-22 15:46:33.670 | Yakalandı |

T1136.001-8 için olay sırası (2026-11-22): 15:46:33.612 4720 (`T1136.001_Admin` açıldı) → 15:46:33.638 4732 Users → 15:46:33.670 4732 Administrators. Son 7 günde toplam 2 olay, ikisi de test.

## Geliştirme fikri

"Yeni açılan hesap kısa süre içinde Administrators'a eklendi": 4720'deki `TargetSid` ile 4732'deki `MemberSid` aynı ve aralarında birkaç dakika varsa daha güçlü bir sinyal. Süre nedeniyle yapılmadı.

## Analistin sonraki adımları

- Kim ekledi (`src_user`)? Bu hesap yönetici atamaya yetkili mi, o saatte oturum açmış mı (4624)?
- Eklenen hesap (`MemberSid`) yeni mi açıldı (4720)? Açıldıktan hemen sonra eklendiyse şüphe artar.
- Ekleme hangi komutla yapıldı? Aynı saatte Sysmon `EventID=1`'de `net.exe`, `net1.exe` veya PowerShell'e bak.
- Eklenen hesap sonradan oturum açtı mı (4624)?
