# hi_res_steaming プロジェクト概要

## プロジェクト目的
録音番組配信型ハイレゾストリーミングWebアプリケーション
- 事前録音された1時間番組を24bit/96kHz FLACで配信
- 番組時間外は自動サインアウト
- サインイン制限による接続人数管理
- 世界配信対応（単一サーバー構成）

## 技術スタック

### 音源フォーマット
- **録音番組**: FLAC 24bit/96kHz（1時間番組、約1.2-1.5GB）
- **配信フォーマット**: FLAC（無劣化配信）

### サーバー構成（東京VPS）
- **OS**: Ubuntu 22.04 LTS
- **ストリーミング**: Liquidsoap + Icecast2
- **認証API**: Node.js + Express
- **Webサーバー**: Nginx（SSL終端・プロキシ）
- **データベース**: Supabase（認証・リスナー管理）

### フロントエンド
- **構成**: 純粋HTML + Vanilla JavaScript
- **認証**: Supabase Auth SDK
- **UI**: サインイン + mute/unmuteボタン + 番組情報表示
- **機能**: 地域検出・遅延測定・番組進行状況

### インフラ
- **VPS**: Vultr Tokyo（4GB/2CPU/1Gbps）月¥3,000
- **DNS/保護**: Cloudflare（無料版）
- **SSL証明書**: Let's Encrypt（自動更新）

## アーキテクチャ

### 単一サーバー構成（東京VPS）
```
[録音番組 FLAC 24bit/96kHz]
       │
       ▼
[Liquidsoap] ← 番組スケジューラー・FLAC配信
       │
       ▼
[Icecast2] ← 認証付きストリーミング・100人制限
       │
       ▼
[Nginx + SSL] ← リバースプロキシ・静的ファイル配信
       │
       ▼
[世界各地のリスナー] ← サインイン必須・番組終了で自動ログアウト
```

### 認証・管理フロー
```
[Supabase Auth] ← メール認証・JWT発行
       │
       ▼
[Node.js API] ← JWT検証・Icecast認証連携
       │
       ▼
[番組スケジューラー] ← 毎時0分強制ログアウト
       │
       ▼
[リスナー管理DB] ← 接続ログ・地域統計
```

## 主要機能

### リスナー機能
- **メール認証必須サインイン**
- **同時聴取**: 全員が同じタイミングで同じ番組を聴く
- **mute/unmuteボタンのみ** のシンプルUI
- **番組情報表示**: タイトル・進行状況・次回終了時刻
- **地域検出**: 接続元地域・推定遅延表示
- **自動サインアウト**: 番組終了時（毎時0分）

### 管理機能
- **接続数制限**: 最大100人同時接続
- **番組スケジューリング**: 1時間番組の自動再生
- **統計情報**: リスナー数・地域分布・接続ログ
- **品質保証**: FLAC 24bit/96kHz無劣化配信

## 実装方法

### Liquidsoap番組スケジューラー
```liquidsoap
#!/usr/bin/liquidsoap
set("log.file.path", "/var/log/liquidsoap/scheduled.log")

# 番組時間判定
def get_current_program() = 
  hour = localtime().tm_hour
  if hour == 20 then  # 20:00-21:00
    "/home/radio/programs/main_program.flac"
  else
    "" # 番組時間外
  end
end

# 番組切り替えハンドラー
def program_handler()
  program = get_current_program()
  if program != "" then
    single(program)  # 番組再生
  else
    # 番組時間外：強制ログアウト実行
    ignore(process.run("curl -X POST http://localhost:3000/force-logout"))
    blank()  # 無音
  end
end

# Icecast出力（認証付き）
output.icecast(
  %flac(samplerate=96000, channels=2),
  host="localhost",
  port=8000,
  password="hackme",
  mount="/stream.flac",
  name="Hi-Res Radio - Scheduled Programs",
  switch([({0m}, program_handler)])  # 毎分チェック
)
```

### Icecast設定（認証付き）
```xml
<icecast>
    <limits>
        <clients>105</clients>
        <sources>1</sources>
    </limits>
    <mount>
        <mount-name>/stream.flac</mount-name>
        <max-listeners>100</max-listeners>
        <authentication type="url">
            <option name="listener_add" value="http://localhost:3000/verify-token"/>
            <option name="auth_header" value="Authorization"/>
        </authentication>
    </mount>
</icecast>
```

### 認証付きフロントエンド
```html
<!DOCTYPE html>
<html lang="ja">
<head>
    <title>Hi-Res Radio - Premium Programs</title>
    <script src="https://unpkg.com/@supabase/supabase-js@2"></script>
</head>
<body>
    <!-- サインイン画面 -->
    <div class="login-screen active">
        <h1>🎵 Hi-Res Radio</h1>
        <p>プレミアム 24bit/96kHz 番組配信</p>
        <form id="signinForm">
            <input type="email" placeholder="メールアドレス" required>
            <input type="password" placeholder="パスワード" required>
            <button type="submit">サインイン</button>
        </form>
        <p>📅 番組時間: 毎日20:00-21:00<br>番組終了で自動サインアウト</p>
    </div>
    
    <!-- プレイヤー画面 -->
    <div class="player-screen">
        <h1>🎵 Hi-Res Radio</h1>
        
        <!-- 番組情報 -->
        <div class="program-info">
            <div class="program-title" id="programTitle">Main Program</div>
            <div class="program-time">📻 Live · FLAC 24bit/96kHz</div>
            <div class="program-progress">
                <div class="progress-bar" id="progressBar"></div>
            </div>
            <div class="next-logout">次回サインアウト: 21:00</div>
        </div>
        
        <audio id="stream"></audio>
        <button id="muteBtn">🔊</button>
        
        <!-- 接続情報 -->
        <div class="connection-info">
            <div>📍 <span id="userLocation">Detecting...</span></div>
            <div>⏱️ Delay: <span id="estimatedDelay">~3-8 seconds</span></div>
            <div>👥 <span id="listenerCount">-/100 listeners</span></div>
        </div>
    </div>
    
    <script>
        // Supabase認証 + ストリーミング接続
        // 地域検出・遅延測定・番組進行管理
    </script>
</body>
</html>
```

## セットアップ手順

### VPS環境構築（5分セットアップ）
```bash
#!/bin/bash
# setup-hires-radio.sh

# 1. システム更新
sudo apt-get update && sudo apt-get upgrade -y

# 2. 必要パッケージインストール
sudo apt-get install -y liquidsoap icecast2 nginx nodejs npm certbot

# 3. ユーザー・ディレクトリ作成
sudo useradd -m radio
sudo -u radio mkdir -p /home/radio/{programs,logs}

# 4. PM2インストール（Node.js管理用）
sudo npm install -g pm2

# 5. ファイアウォール設定
sudo ufw allow 80,443,8000/tcp
sudo ufw --force enable

echo "✅ Setup completed! Upload your program files to /home/radio/programs/"
```

### 番組ファイル配置
```bash
# 1時間番組をアップロード
scp main_program_20241201.flac user@server:/home/radio/programs/

# 音質確認
ffprobe -v quiet -print_format json -show_streams main_program.flac | \
  jq '.streams[0] | {sample_rate, bits_per_sample, channels, duration}'
```

### 起動・運用
```bash
# サービス開始
sudo systemctl start icecast2 nginx
sudo -u radio liquidsoap /home/radio/scheduled.liq
pm2 start auth-server.js --name radio-api

# 状態確認
curl -I https://radio.example.com/stream.flac
pm2 status
sudo systemctl status icecast2
```

## メリット・特徴

### 録音番組配信のメリット
- **完璧な音質制御**: 事前マスタリングで最高品質を保証
- **安定配信**: リアルタイム処理エラーなし
- **確実なスケジュール**: 番組時間を正確に管理
- **世界配信対応**: 単一サーバーから全世界へ配信
- **接続制限**: サインインによる100人制限で品質維持

### 技術的特徴
- **無劣化配信**: FLAC 24bit/96kHz完全維持
- **低コスト運用**: 月¥3,100（VPS+ドメイン）
- **自動管理**: 番組終了で全リスナー自動サインアウト
- **統計機能**: リスナー地域分布・接続ログ

### セキュリティ・制御
- **認証必須**: Supabaseメール認証
- **JWT連携**: Icecast認証システム
- **時間制限**: 番組時間外はアクセス不可
- **接続監視**: リアルタイム接続状況管理

## 運用コスト

| 項目 | 月額費用 | 年額費用 |
|------|---------|---------|
| Vultr VPS Tokyo | ¥3,000 | ¥36,000 |
| ドメイン (.com) | ¥100 | ¥1,200 |
| Supabase | ¥0 | ¥0 |
| Cloudflare | ¥0 | ¥0 |
| SSL証明書 | ¥0 | ¥0 |
| **合計** | **¥3,100** | **¥37,200** |

**対応人数**: 100人同時接続  
**配信地域**: 世界全域  
**音質**: 完全無劣化FLAC