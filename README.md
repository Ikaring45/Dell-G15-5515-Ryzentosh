# Dell G15 5515 Ryzentosh

Dell G15 5515（Ryzen 7 5800H／RTX 3060 Laptop GPU）でmacOSを起動し、日常機能を実機検証するプロジェクト。現在の対象は macOS Tahoe 26.7.3（25G342）と OpenCore 1.0.8。

## 実機で確認したこと

| 項目 | 結果 |
| --- | --- |
| 内蔵SSDから起動 | USBなしでTahoeが起動。通常の起動で文字ログを非表示にできた |
| RTX 3060 | Hybrid Graphics Disabledで内蔵画面を駆動。6 GBとMetal 4を認識し、Metalの計算・描画を実行できた |
| 外部出力 | HDMIを接続したままBUFFALO USBから起動し、2560×1440・60 Hzで表示。起動後の挿し直しではRTXがEDIDを読んだがmacOSの一覧に出なかった |
| ネットワーク | 標準Wi-Fiと有線LANを使用できた |
| 音声・カメラ | スピーカー、イヤホン出力、内蔵UVCカメラを認識。マイク入力は未確認 |
| 壁紙 | ログイン後のロック画面で動作を目視確認。初回ログイン画面では静止 |
| 輝度 | RTX直結ではファームウェアがGPU制御を報告。現行NVKMSで輝度取得に失敗しており、Fnキーでの調節は未達 |
| トラックパッド | ポインタはPS/2で動作。I²CマルチタッチのUSB試験は起動途中で停止 |
| AirDrop | Finderの探索・Bluetooth広告を確認。AWDLインターフェースは確認できず、iPadとの双方向実転送は未達 |
| Apple Music MV | 公開H.264配信はデコードできた。Apple MusicのMVはVideoToolboxの `-12906` で失敗 |
| UI | アイコン欠けとメニューの透過異常が残る。GPUの基本的な半透明描画テストは成功 |

## 構成と検証

- [efi/config.example.plist](efi/config.example.plist) はUSBなしで起動を確認したRTX直結構成から作成。端末固有のSMBIOS識別値は空欄またはゼロに置換している。単体では起動できない。OpenCore 1.0.8に合わせ、参照するACPI・ドライバー・kextを揃えたうえで、自分の識別値を設定する。
- [patches](patches/) にNullMoth 2.9向けPCI識別子・グラフィックスエンジン使用率と、Stats 3.0.26向けのFPS表示パッチを収録。PCI識別子は実機のIORegistryで確認済み。グラフィックスエンジン版はビルドまで、Statsはパッチの適用と計測コードの実機実行まで。Stats本体の表示とTiler使用率は未確認。
- [diagnostics](diagnostics/) にMetal・アプリ起動・アイコン・画面更新の計測コードと、輝度制御元を読むカーネル拡張のソースを収録。画面更新回数はデスクトップのフレーム転送回数。
- ベース構成には実験ドライバーを読み込むためのAMFI・SIP関連設定が含まれる。適用前に動作確認済みのEFIを保存し、検証用USBと内蔵EFIの起動結果を個別に確認する。

## 参照先

- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg)
- [AMD Vanilla](https://github.com/AMD-OSX/AMD_Vanilla)
- [NullMoth NVIDIA macOS driver v2.9](https://github.com/nullmoth/nvidia-macos-driver/tree/v2.9)
- [Stats v3.0.26](https://github.com/exelban/stats/tree/v3.0.26)
- [Dell G15 5800HのI²Cトラックパッド構成](https://github.com/nhatminhtrieu/DellG15-5800H-Hackintosh)

パッチ先のプロジェクトや各ドライバーには、それぞれのライセンスが適用される。
