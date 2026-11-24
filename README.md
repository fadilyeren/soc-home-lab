# SOC Home Lab

A SOC homelab built with Splunk Enterprise, Sysmon and Atomic Red Team. Five attack scenarios, each with an SPL detection, false positive analysis and test evidence. The brute-force detection was turned into a scheduled alert and triggered.

**Site:** https://fadilyeren.github.io/soc-home-lab/ (Turkish, with an English version via the TR/EN button in the top right)

## Lab

| Component | Role |
|---|---|
| Windows 10 VM (VirtualBox) | Victim. Sysmon (SwiftOnSecurity configuration), PowerShell Script Block Logging (4104), Splunk Universal Forwarder |
| Kali Linux VM | Attacker (scenario 5) |
| Host machine | Splunk Enterprise; `wineventlog` and `sysmon` indexes |

The VMs are on a VirtualBox host-only network (`192.168.56.0/24`). The forwarder runs as `NT SERVICE\SplunkForwarder` instead of Local System, with read-only access to the event logs.

## Scenarios

| # | Scenario | ATT&CK | Detection |
|---|---|---|---|
| 1 | Discovery commands | T1033, T1087.001, T1082 | [01-kesif-komutlari.md](detections/01-kesif-komutlari.md) |
| 2 | Encoded PowerShell | T1059.001, T1027 | [02-sifreli-powershell.md](detections/02-sifreli-powershell.md) |
| 3 | Adding a member to Administrators | T1098, T1136.001 | [03-yonetici-grubuna-ekleme.md](detections/03-yonetici-grubuna-ekleme.md) |
| 4 | Persistence via Run keys | T1547.001 | [04-run-anahtari-kalicilik.md](detections/04-run-anahtari-kalicilik.md) |
| 5 | Brute force over SMB (alert) | T1110.001 | [05-kaba-kuvvet-smb.md](detections/05-kaba-kuvvet-smb.md) |

## Folders

- `detections/`: detection documents (attack steps, SPL, tuning notes, test evidence, analyst next steps). Written in Turkish.
- `lab/universal-forwarder/`: the `soc_lab_forwarder` forwarder app and its install script
- `lab/sysmon/`: Sysmon configuration and its source
- `lab/windows-vm/`: Windows VM logging settings
- `index.html`, `senaryolar/`, `css/`, `img/`: the GitHub Pages site (plain HTML/CSS), Turkish
- `en/`: the English version of the site

The documents under `detections/` and `lab/` are in Turkish; the site has an English version.

## Sources and licenses

- Sysmon configuration: [SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config), CC BY 4.0.
- The detection document headings were adapted from the structure of [srkyn/splunk-detection-content](https://github.com/srkyn/splunk-detection-content) (MIT).

All tests were run in my own isolated lab. No real malware was used.
