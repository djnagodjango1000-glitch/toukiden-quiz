# Androidテスト用APK 0.7.0

[APKをダウンロード（約86 MiB）](https://github.com/djnagodjango1000-glitch/toukiden-quiz/raw/refs/heads/codex/apk-0.7.0/android/kimon-senki-0.7.0-debug.apk)

開発途中の**デバッグ署名付きテスト版**。広告・課金は実装していない。Godot 4.6.3、縦画面、アプリID `jp.kimonsenki.offline`、versionCode 7、バージョン0.7.0。Android 7.0（API 24）以上、arm64-v8a（Pixel 6aに対応するCPU形式）とx86_64を含む。

APKのSHA-256：`9b2e672cc1892d63b7fc54ad06163b3ec3ebf96081dcbfb2dcb7bad078133bd5`。

`apksigner verify`でv2/v3署名を検証。`aapt dump permissions`ではINTERNETや課金権限を含む追加権限の宣言なし。0.6.0と0.7.0は同じパッケージ名・同じ署名証明書（SHA-256 `47acf8dc2b64dd402a0f673b5c368438decb46596a96cce5c76dabfc98beed0a`）で、0.7.0のversionCodeは6から7に増加。保存形式を初期化する変更はない。

0.6.0についてはユーザーからAndroid端末でのインストール・試遊の報告あり。**0.7.0をAndroid端末で上書きインストールし、既存セーブが保持されるかは未検証。** 異なる署名のアプリを上書きするために既存アプリを削除するとセーブも失われ得るので、削除・初期化を案内しない。アプリのバックアップ機能とAndroidのファイル選択・復元も実機未検証。

一時的なデバッグ署名鍵はGitに含めていない。将来鍵が失われた場合、別署名のAPKは同一アプリに上書きできない。正式配布には安全に管理したリリース署名鍵と更新手順が必要。

## ビルド手順
Godot 4.6.3のAndroid書き出しテンプレート、JDK 21、Android SDKのplatform-tools/build-toolsと既存のデバッグ署名鍵を設定し、次を実行する。

```sh
godot --headless --editor --import --path . --quit
godot --headless --path . --export-debug Android build/kimon-senki-0.7.0-debug.apk
apksigner verify --verbose --print-certs build/kimon-senki-0.7.0-debug.apk
aapt dump permissions build/kimon-senki-0.7.0-debug.apk
```

前回Android 35エミュレーターはハードウェア仮想化なしで起動を試行したが、約6分間ADBがofflineのままでインストール・起動に至らなかった。0.7.0のエミュレーター・Pixel 6a実機は未検証。正式リリースでは署名鍵の安全な保管、実機検証、バックアップ復元、更新互換性、問題校閲が必要。
