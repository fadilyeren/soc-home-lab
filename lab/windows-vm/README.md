# Windows VM ayarları

Windows 10 kurban VM'inde, daha iyi görünürlük için yapılan günlük (log) ayarları. Her ayar bir betikle yapılır; betikler VM içinden, salt okunur paylaşılan klasörden (`\\VBOXSVR\homelab`) yönetici PowerShell'de çalıştırılır.

| Betik | Ne açar | Splunk'ta nerede görünür |
|---|---|---|
| `powershell-kaydi.ps1` | PowerShell Script Block Logging (Olay 4104) | `index=wineventlog source="XmlWinEventLog:Microsoft-Windows-PowerShell/Operational"` |

## PowerShell Script Block Logging (Olay 4104)

**Ne işe yarar:** PowerShell'in çalıştırdığı kodun içeriğini kaydeder. Kod gizlenmiş (ör. Base64 ile kodlanmış) olsa bile PowerShell onu çalıştırmadan önce çözer ve çözülmüş hâli kaydeder. Bu yüzden saldırı tespitinde en değerli Windows olaylarından biridir.

**Nasıl açılır:**

```powershell
powershell -ExecutionPolicy Bypass -File \\VBOXSVR\homelab\windows-vm\powershell-kaydi.ps1
```

Betik ayarı açar, zararsız ve işaretli bir test komutu çalıştırır (`SOCAGENT-4104-TEST-...`) ve bunun Olay 4104 olarak kaydedildiğini kontrol eder. Ardından Splunk'ta işaretle aranır:

```spl
index=wineventlog earliest=-15m "SOCAGENT-4104-TEST"
```

**Doğrulama (2026-11-07):** Splunk'ta iki 4104 olayı görüldü:
- Test komutu (`Write-Output 'SOCAGENT-4104-TEST-...'`), Level 5 (bilgi).
- Betiğin kendisi, **Level 3 (uyarı)**. PowerShell'in yerleşik "şüpheli kod" denetimi, kayıt ayarlarını değiştiren kodu ayar kapalıyken bile uyarı olarak kaydeder. Saldırganlar izlerini gizlemek için bu ayarı kapatmaya çalıştığından (MITRE ATT&CK: Impair Defenses), bu davranış ayrıca bir tespit fırsatıdır.

**Bilinmesi gerekenler:**
- Ayar yalnızca yeni başlayan PowerShell süreçlerinde geçerlidir.
- Bu ayar Windows PowerShell 5.1 içindir. PowerShell 7 ayrı bir yol ve ayrı bir günlük (`PowerShellCore/Operational`) kullanır.
- Gerçek bir şirkette bu günlükler betiklerdeki şifre gibi hassas bilgileri de içerebilir. Bu yüzden erişimleri kısıtlanır ve saklama süreleri planlanır.
- Geri almak için:
  ```powershell
  Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -Value 0
  ```
