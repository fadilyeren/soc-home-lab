# SMB/RDP üzerinden kaba kuvvet (çok sayıda başarısız ağ girişi)

**Durum:** uyarı (zamanlanmış uyarı kuruldu ve test edildi)

## Ne tespit eder

Tek bir kaynak IP'den kısa sürede çok sayıda başarısız ağ/RDP girişini (4625, Logon Type 3 ve 10) tespit eder. Kaba kuvvet ve parola püskürtme bu izi bırakır.

## ATT&CK eşlemesi

- T1110.001 Brute Force: Password Guessing

## Gerekli veri kaynakları

- Index `wineventlog`, Windows Security günlüğü
- `EventID=4625` (başarısız giriş); alanlar `src_ip` (ham: `IpAddress`), `Logon_Type`, `Status`, `Sub_Status`
- İnceleme için `EventID=4740` (hesap kilitlendi)
- Senaryo 5 için VM güvenlik duvarında "Lab SMB host-only" kuralı (TCP 445, yalnızca 192.168.56.0/24) gerekli.

## Saldırı adımları

Kali (192.168.56.50) → Windows VM (192.168.56.102), yalnızca host-only ağ:

```bash
printf '%s\n' password 123456 admin letmein qwerty Welcome1 Passw0rd summer2024 winter2024 dragon monkey football iloveyou abc123 changeme > ~/parolalar.txt
nxc smb 192.168.56.102 -u <kullanici> -p ~/parolalar.txt
```

Hydra v9.7 önce denendi, SMB modülü modern SMBv2/3 ile anlaşamadı (`[ERROR] invalid reply from target`); netexec kullanıldı. `<kullanici>` hesabı 10 denemeden sonra Windows'un varsayılan kilitleme politikasıyla kilitlendi; tekrar testleri var olmayan `testuser` ile yapıldı (kilitlenmez, yine 4625 üretir).

## SPL

```
index=wineventlog EventID=4625 Logon_Type IN (3,10)
| stats count by src_ip
| where count > 9
```

- `Logon_Type IN (3,10)`: ağ (SMB) ve RDP girişleri. Baseline'daki Logon Type 2 (ekrandan, kullanıcının kendi hatalı girişleri) kapsam dışı.
- `by src_ip`: her kaynak ayrı sayılır. Hem tek hesaba kaba kuvveti hem de bir IP'den birçok hesaba parola püskürtmeyi yakalar.
- `where count > 9`: 10+ başarısız giriş. Gerekçe: parolasını unutan kullanıcı 5-6 kez dener; Windows'un kilitleme sınırı da 10.
- Zamanlanmış uyarıda `_time`/`bin` yok; zaman penceresini uyarının kendisi sağlar.

## Zamanlanmış uyarı

Splunk Save As → Alert:

- Alert type: Scheduled, Cron `*/5 * * * *`, Time Range **Last 5 minutes**
- Trigger: Number of Results > 0, Once
- Action: Add to Triggered Alerts, Severity High

İlk kurulum 1 dakikalık pencereyle yapıldı ve **tetiklenmedi**: olaylar forwarder'dan indexlenene kadar geçen gecikmeyle 1 dakikalık pencereye girmedi. Çalışma aralığı ve pencere 5 dakikaya çıkarılınca sorun çözüldü. (Ders: zamanlanmış uyarıda aralık ve pencere, veri gecikmesini hesaba katacak genişlikte olmalı; ayrıca aralık = pencere olmalı ki üst üste binme veya boşluk olmasın.)

## Ayıklama / yanlış alarm notları

- Baseline: lab'da son 7 günde ağ üzerinden (Logon Type 3) başarısız giriş **sıfır**. Yalnızca 2 adet Logon Type 2 (kullanıcının süresi dolmuş parolayla kendi girişi, `0xc000006e`); kapsam dışı.
- Eski parolalı bir servis tek kaynaktan sürekli 4625 üretebilir (BOTS v2'deki 10.0.1.220 → Administrator örneği gibi). Gerçek ortamda böyle bir kaynak çıkarsa IP beyaz listeye alınır veya servisin parolası düzeltilir.

## Bilinen sınırlamalar

- Eşik (10) Windows'un kilitleme sınırına (10) eşit. Kilitleme sınırı daha düşük bir makinede saldırgan 10'a varmadan hesap kilitlenir, 4625'ler kesilir ve kural kaçırabilir.
- Sabit 5 dakikalık pencere, iki pencereye yayılan yavaş bir saldırıyı bölebilir (her pencere eşiğin altında kalır). Kayan pencere bunu çözer ama zamanlanmış uyarılar sabit pencere kullanır.
- Kilitli hesaba gelen sonraki denemeler 4625 üretmedi; saldırının ilk 10 denemesi yakalandı.

## Test kanıtı

| Adım | Saat (2026-11-22) | Sonuç |
|---|---|---|
| Saldırı 1 (`<kullanici>`) | 19:01 | 11 adet 4625 (Type 3) + 1 adet 4740; hesap kilitlendi |
| Manuel tespit sorgusu | 19:52 | `192.168.56.50` count 27 |
| Tekrar saldırı (`testuser`) + uyarı | 20:00 | Uyarı tetiklendi: Triggered Alerts, High, 20:00:01 |

Saldırının izi: 10 adet 4625 `Sub_Status 0xc000006a` (yanlış parola) + 1 adet keşif (`0x80090308`, netexec'in el sıkışması) + 1 adet 4740 (hesap kilitlendi). Hepsi Logon Type 3, kaynak 192.168.56.50.

## Analistin sonraki adımları

- `src_ip` kime ait, bu makinenin o IP ile konuşması normal mi?
- Başarısız denemelerin ardından aynı kaynaktan **başarılı** bir giriş (4624, Logon Type 3) var mı? Varsa kaba kuvvet başarılı olmuş olabilir.
- Hangi hesaplar hedeflendi (tek hesap = kaba kuvvet, çok hesap = parola püskürtme)?
- 4740 (hesap kilitlendi) oluştu mu? Hangi hesaplar etkilendi?
- Saldırı kaynağını ağ düzeyinde engelle; hesap kilidi saldırıyı durdurmaz, yalnızca o hesabı korur.
