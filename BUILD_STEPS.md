# Luvio Player - GitHub Actions build steps

Same flow as the coloring app.

## 1. Repo me daalo
1. Is zip ko extract karo.
2. Saari files (including hidden `.github` folder) GitHub repo me drag-and-drop / push karo.
   - Zaroori: `.github/workflows/build-apk.yml` upload hona chahiye, warna Actions run nahi hoga.

## 2. Build chalao
1. GitHub -> **Actions** tab -> "Build Luvio Player APK" -> run apne aap start ho jayega (push par) ya **Run workflow** dabao.
2. ~10-15 min lagenge (Flutter + Gradle first-time cache).
3. Green tick ke baad neeche **Artifacts** -> `luvio-player-apk` download karo.
   - Andar milega: `app-debug.apk`, `app-release.apk`, `app-release.aab`

Agar build red ho jaye to poora log copy karke bhej dena - fix kar denge.

## 3. Test
- `app-debug.apk` ko Fire tablet par sideload karo (ya Appetize.io par chalao).
- Check karo: splash -> permission screen -> folder list dikhe -> video khule -> gestures (brightness/volume/seek) -> subtitle -> PiP -> vault -> file manager.

## 4. Signing (release ke liye)
Amazon khud re-sign karta hai, par proper signed APK better hai.

Apne PC par ek baar keystore banao:
```bash
keytool -genkey -v -keystore luvio-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias luvio
base64 -w0 luvio-release.jks > keystore.txt
```

GitHub repo -> Settings -> Secrets and variables -> Actions -> New repository secret:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `keystore.txt` ka poora content |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | `luvio` |
| `KEY_PASSWORD` | key password |

Secrets add karne ke baad dobara workflow chalao - ab `app-release.apk` properly signed hoga.
Secrets nahi honge to bhi build pass hoga, bas release APK debug-signed rahega (testing ke liye theek hai).

## 5. Amazon Appstore
- Binary: `app-release.apk`
- Device support: saare Fire Tablets rakho, Fire TV hata do (touch/gesture app hai)
- Privacy policy URL zaroori hai

## Config summary
| Cheez | Value |
|---|---|
| Package | `dev.luvio.player` |
| Version | 2.6.0 (5100) |
| minSdk / targetSdk / compileSdk | 21 / 35 / 35 |
| Flutter (CI) | 3.24.5 stable |
| Java (CI) | 17 |
| Renderer | Skia (Impeller off - purane Fire GPUs ke liye) |
