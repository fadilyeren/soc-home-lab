# Sysmon yapılandırması (Windows VM)

Windows 10 kurban VM'inde çalışan Sysmon'un yapılandırması. Sysmon, süreç başlatma, ağ bağlantısı, dosya ve kayıt defteri değişiklikleri gibi olayları Windows olay günlüğüne yazar. Universal Forwarder bu olayları Splunk'taki `sysmon` index'ine gönderir.

## Kaynak ve lisans

| | |
|---|---|
| Dosya | `sysmonconfig.xml` (kaynaktaki adı `sysmonconfig-export.xml`) |
| Kaynak | [SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config), `master` dalı |
| Sürüm | 74 (2021-07-08); kaynaktaki son değişiklik 2021-10-17 |
| Şema | Sysmon schema 4.50 (Sysmon 13 ve üstü gerekir; VM'de 15.22 var) |
| Lisans | [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). Dosya, SwiftOnSecurity'nin çalışmasıdır ve değiştirilmeden kopyalanmıştır. |
| İndirme tarihi | 2026-11-07 |

## Doğrulama

Dosyanın SHA256 değeri, VM'de `Sysmon64.exe -c` komutunun bildirdiği yapılandırma hash'iyle aynıdır:

```text
055FEBC600E6D7448CDF3812307275912927A62B1F94D0D933B64B294BC87162
```

Yani VM'de çalışan yapılandırma bu dosyanın kendisidir. Dosya `.gitattributes` ile satır sonu dönüşümünden korunur; böylece hash değişmez.

Kontrol etmek için VM'de:

```powershell
Sysmon64.exe -c | Select-String "Config hash"
```

## VM'e uygulama

Bu dosya değiştirilirse VM'e paylaşılan klasörden uygulanır (yönetici PowerShell):

```powershell
Sysmon64.exe -c \\VBOXSVR\homelab\sysmon\sysmonconfig.xml
```

## Planlanan özelleştirmeler

- Gürültüyü ölçerek azaltmak. İlk ölçümde (2026-11-07) olay 1 gürültüsünün çoğu VM'den kaldırılan eski Splunk Enterprise'dan geliyordu; o kaynak artık yok. Kalan gürültü forwarder'ın kendi yardımcılarıydı; Sysmon'da değil, forwarder'da kapatılarak çözüldü (ayrıntı: `lab/universal-forwarder/README.md`). Olay 13'ün çoğu Windows telemetrisinden (`CompatTelRunner.exe`) geliyor. Hariç tutma kuralları yalnızca ölçümle doğrulanmış kaynaklar için, dar tutularak (tam program yolu, gerekirse olay türü ve üst süreç koşuluyla) yazılır; geniş klasör hariç tutmaları kör nokta yaratır.
- Tespit senaryolarına göre gerekli olay türlerini (ör. olay 10) seçici olarak açmayı değerlendirmek.

Değişiklik yapılırsa bu README'deki kaynak tablosuna "değiştirildi" notu ve yapılan değişikliklerin listesi eklenmeli (lisansın kaynak belirtme şartı).
