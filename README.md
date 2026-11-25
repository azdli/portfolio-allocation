# Portfolio Allocation

A lightweight, private, and manual macOS app for tracking holdings across brokerage accounts, seeing your allocation at a glance, and deciding what to buy next.

<img width="2672" height="1522" alt="demo" src="https://github.com/user-attachments/assets/3647561f-68e6-46b6-8198-55232efb0231" />
*Demo Portfolio*

## Features

- **Simple entry.** Copy each position's total shares and cost basis from your brokerage's positions page. Update them inline as they change.
- **Allocation at a glance.** A donut chart by holding or asset class, plus each account's value and gain.
- **Targets and buy suggestions.** Set target percentages, see how far each holding is from its target, and enter a cash amount to see how to split it. Optionally, measure targets against only the holdings that have one.
- **Private by design.** Your portfolio is encrypted (AES-256-GCM) with a key kept in your login keychain and stored only on your Mac. Your portfolio is only readable on your Mac device. The app also has no network access.

## Requirements

- macOS 27 or later
- Xcode 27 (Build from source only)

## Install

1. Download the latest `Portfolio-Allocation-<version>.dmg` from [Releases](../../releases).
2. Open it and drag **Portfolio Allocation** onto **Applications**.
3. Open the app. The first time, macOS blocks it because it isn't notarized by Apple. Go to **System Settings › Privacy & Security**, scroll down, click **Open Anyway**, and confirm with your password. After that it opens normally. You may need to do this again after downloading an update.
4. When macOS asks to let the app use its keychain item, choose **Always Allow**. It asks again after each update, because the app is signed for local use rather than with a Developer ID.

### Build from source

```sh
git clone https://github.com/azdli/portfolio-allocation.git
cd portfolio-allocation
./install.sh
```

`install.sh` builds a Release copy, signs it for local use, and installs it in `/Applications`. Run it again to update. `./install.sh --dmg` builds the release disk image in `dist/` instead.

## Delete your data

Settings › Data shows where your encrypted portfolio file is saved, and can permanently delete it, along with its key.

To uninstall, use **Settings › Data › Delete Portfolio…** before moving the app to the Trash to properly delete the encrypted file and its key on your Mac.

## License

MIT. See [LICENSE](LICENSE).
