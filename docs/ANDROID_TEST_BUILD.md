# Androidテスト用APK 0.6.0

## 内容と制限
[APKをダウンロード（約84 MiB）](https://github.com/djnagodjango1000-glitch/toukiden-quiz/raw/refs/heads/codex/apk-0.6.0/android/kimon-senki-debug.apk)

これは開発途中の**デバッグ署名付きテスト版**。広告・課金は実装していない。Godot 4.6.3、縦画面、アプリID `jp.kimonsenki.offline`、versionCode 6、バージョン0.6.0。Android 7.0（API 24）以上を対象に、arm64-v8a（Pixel 6a対応のCPU形式）とx86_64を含む。

生成APKのSHA-256：`ea4f5cf460d4326745f90ff953de3d5dd956c90df15d22a3a4e5dfc518e0d13f`。

`apksigner verify`でv2/v3署名の検証成功。`aapt dump permissions`では追加のAndroid権限の宣言なし（INTERNETや課金権限なし）。アプリのオフライン処理はコードレベルで確認した。APKの自動デバッグ署名は開発環境の一時鍵であり、将来その鍵が失われた場合、別の署名のAPKは同一アプリへ上書き更新できない。正式配布には安全に管理したリリース署名鍵と更新手順が必要。

## インストール
デバッグAPKをAndroid端末へ転送し、端末のファイルアプリから開く。Androidがインストール元の許可を求めた場合は、内容と発行元を確認してから操作する。インストール後はホーム画面の「鬼問戦記」から起動。

アプリ内のバックアップ機能はLinux環境で検証済み。Androidのファイル選択・バックアップ復元は未検証。別署名のAPKに更新できない場合に既存アプリを削除するとセーブも失われ得るため、既存データの削除や初期化を自動実行しない。

## ビルド手順
Godot 4.6.3のAndroid書き出しテンプレート、JDK 21、Android SDKのplatform-tools/build-tools、デバッグ署名鍵を用意し、GodotエディターのAndroid設定を指定する。`export_presets.cfg`のAndroidプリセットから次を実行する。

```sh
godot --headless --editor --import --path . --quit
godot --headless --path . --export-debug Android build/kimon-senki-debug.apk
apksigner verify --verbose --print-certs build/kimon-senki-debug.apk
aapt dump permissions build/kimon-senki-debug.apk
```

鍵・SDK・ローカルのエディター設定はリポジトリに含めない。正式リリースでは署名鍵の安全な保管、OS実機検証、バックアップ復元、Android更新互換性、問題校閲が必要。

## 今回の起動検証
Android 35のエミュレーターをソフトウェア仮想化で起動したが、約6分間ADBがofflineのままで、APKのインストール・起動まで進めなかった。Pixel 6a実機も未接続。署名や権限の検証は、端末での動作確認を意味しない。
