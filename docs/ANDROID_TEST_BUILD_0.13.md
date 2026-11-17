# Androidテスト版 0.13.0

[APKをダウンロード](https://github.com/djnagodjango1000-glitch/toukiden-quiz/raw/refs/heads/codex/apk-0.13.0/android/kimon-senki-0.13.0-debug.apk)

開発中のデバッグ署名版。Android 7.0以上・64ビットARM（arm64-v8a）の端末向け。Pixel 6aのCPU形式に対応する。ダウンロードサイズを抑えるため、今回のAPKはx86_64エミュレーター用バイナリを含まない。広告・現実のお金による課金・ログインはない。

0.12.0と同じパッケージ名・署名証明書で、versionCodeは13。既存アプリを削除せず更新することを想定しているが、Android実機での上書き更新やセーブ保持は未検証。既存アプリの削除はデータ喪失につながるため行わない。ミタマのID・所持・編成・レベル・進化・通貨は変更しない。聖徳太子のタマフリ効果は変更した。

SHA-256：`ffc086dafcacccd8511ec00f468cd52932d995901315a485dd452ec964dc7349`。v2/v3署名を検証し、Androidの追加権限宣言がないことを確認。署名証明書のSHA-256は`47acf8dc2b64dd402a0f673b5c368438decb46596a96cce5c76dabfc98beed0a`で0.12.0と一致。Android端末・エミュレーターでの0.13.0の起動・操作・セーブ復元は未検証。
