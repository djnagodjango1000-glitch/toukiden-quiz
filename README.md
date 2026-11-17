# 鬼問戦記（開発中）

『クイズバトル討鬼伝』の機能的なゲーム体験を調査し、独自素材で構築する非公式Android向けクイズRPG。原作の画像・音源・ロゴ・問題文は含めません。

**現在：四択101問・○×51問とAndroidデバッグAPKを用意した0.6.0試作。完成版ではありません。**

[AndroidテストAPKをダウンロード（約84 MiB）](https://github.com/djnagodjango1000-glitch/toukiden-quiz/raw/refs/heads/codex/apk-0.6.0/android/kimon-senki-debug.apk)

このAPKはデバッグ署名付きの開発版です。Android実機・エミュレーターでのインストールと起動はまだ確認できていません。

## 実行
Godot **4.6.3**で`project.godot`をインポートしてF6ではなくF5で起動。コマンドラインでは：

```sh
godot --editor --path .
godot --path .
```

タイトル→里→任務→仮の領域→初陣→出陣。巻物を選択し20秒以内に四択へ解答。複数敵の対象はHP欄をタップして変更。初陣達成で連戦、連戦達成で大型鬼任務が解放されます。

4秒以内の正解でハヤフリ。正解を重ねると各ミタマのタマフリとムスヒを使えます。大型鬼は角・左右腕を選んで破壊可能。能力・閾値・倍率は原作未確認の仮値です。

## 資料
- [原作調査・仕様の確度](RESEARCH.md)
- [画面比較と実装前設計](UI_COMPARISON.md)
- [開発構成](ARCHITECTURE.md)
- [Phase 2の動作・仮値](PHASE2_SPEC.md)
- [実装状況・相違点・残課題](STATUS.md)
- [テスト結果](TEST_RESULTS.md)
- [問題の出典と照合状況](docs/QUESTION_REVIEW.md)
- [Androidテスト版のビルド・インストール](docs/ANDROID_TEST_BUILD.md)
- [更新履歴](CHANGELOG.md)
- [素材とフォント](assets/NOTICE.md)

## テスト
```sh
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/test_phase2.gd
godot --headless --path . --script tests/test_progression.gd
godot --headless --path . --script tests/test_offline_policy.gd
godot --headless --path . --script tests/test_questions.gd
# X11画面があるLinux環境。音声装置のない環境ではDummyを指定。
godot --audio-driver Dummy --path . --script tests/ui_flow.gd
godot --audio-driver Dummy --path . --script tests/ui_phase2.gd
godot --audio-driver Dummy --path . --script tests/ui_phase3.gd
godot --audio-driver Dummy --path . --script tests/ui_phase3_extra.gd
godot --audio-driver Dummy --path . --script tests/ui_phase4.gd
```
UIテストは`build/`にPNGを出力します。実セーブと別名のテスト用ファイルを使い、そのファイルのみ後片付けします。

## Android
Godot 4.6.3対応のAndroid書き出しテンプレート、JDK、Android SDKが必要です。AndroidデバッグAPKを生成し、署名と権限を確認しました。Pixel 6a実機での動作は未検証です。詳細はAndroidテスト版の説明を参照してください。ソースをAPKとしてインストールすることはできません。

## 保存
端末内の`user://save.json`に任務報酬を自動保存。検証済み一時ファイルから置換し、前世代を`.bak`に保持。破損時はバックアップを利用し、両方破損または未知の新形式なら上書きを停止します。保存失敗時は結果画面で再試行できます。既存ファイルを自動初期化する処理はありません。通常セーブには個人情報を保存しません。

新規コードの再配布ライセンスは未設定です。フォントには同梱のSIL OFL 1.1が適用されます。
