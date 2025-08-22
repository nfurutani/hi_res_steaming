# hi_res_steaming プロジェクト概要

## プロジェクト目的
デュアルストリーミング対応ハイレゾライブ配信Webアプリケーション
- 24bit/96kHz FLAC音源のリアルタイム配信
- Chrome/Firefox: OGG FLAC直接再生
- Safari: HLS ALAC配信（fMP4セグメント）
- 全ブラウザ対応の同期ライブストリーミング
- Docker環境での統合配信システム

## 技術スタック

### 音源フォーマット
- **入力音源**: FLAC 24bit/96kHz
- **配信フォーマット**: 
  - Chrome/Firefox: OGG FLAC 24bit/96kHz
  - Safari: HLS ALAC 24bit/96kHz（fMP4セグメント）

### サーバー構成（Docker環境）
- **コンテナ化**: Docker + Docker Compose
- **ストリーミング**: Liquidsoap + Icecast2 + ffmpeg
- **デュアル配信**: OGG FLAC（Icecast2）+ HLS ALAC（ffmpeg）
- **FIFO連携**: Liquidsoap → ffmpeg（/tmp/live.fifo）
- **CORS対応**: Python3 HTTPサーバー（Safari HLS用）

### フロントエンド
- **構成**: 純粋HTML + Vanilla JavaScript
- **ブラウザ検出**: Safari自動判定によるストリーミング方式切り替え
- **Safari**: HLS.js + ネイティブHLS再生
- **Chrome/Firefox**: Audio要素による直接OGG FLAC再生
- **UI**: Listen/Stopボタン + ストリーミング状況表示

### 開発環境
- **Docker**: コンテナ化による環境統一
- **ポート構成**: 
  - 8000: Icecast2（OGG FLAC）
  - 8081: CORS HTTP Server（HLS ALAC）
  - 1234: Liquidsoap telnet
  - 3000: Web Interface

## アーキテクチャ

### デュアルストリーミング構成
```
[FLAC音源ファイル 24bit/96kHz]
           │
           ▼
[Liquidsoap] ────┬──► [Icecast2] ──► Chrome/Firefox (OGG FLAC)
                 │
                 └──► [FIFO pipe] ──► [ffmpeg] ──► [HLS fMP4] ──► Safari (ALAC)
                                                        │
                                                        ▼
                                              [CORS HTTP Server]
```

### ブラウザ別配信フロー
```
Chrome/Firefox:
FLAC音源 → Liquidsoap → Icecast2 → OGG FLAC → Audio要素

Safari:
FLAC音源 → Liquidsoap → FIFO pipe → ffmpeg → HLS ALAC → HLS.js/ネイティブHLS
```

### Docker構成
```
hires-radio コンテナ:
- Liquidsoap（音源管理・デュアル出力）
- Icecast2（OGG FLAC配信）
- ffmpeg（FIFO → HLS ALAC変換）
- Python3 CORS Server（Safari HLS用）

web-server コンテナ:
- Node.js（Web Interface）
- 静的ファイル配信
```

## 主要機能

### ブラウザ対応
- **Safari**: HLS ALAC 24bit/96kHz（fMP4セグメント、6秒間隔）
- **Chrome/Firefox**: OGG FLAC 24bit/96kHz（直接ストリーミング）
- **自動検出**: User-Agentによるブラウザ判定と配信方式切り替え
- **同期再生**: 全ブラウザで同一音源の同期ライブ配信

### 技術機能
- **デュアルストリーミング**: 単一音源から複数フォーマット同時配信
- **FIFO連携**: Liquidsoap → ffmpeg リアルタイム変換
- **CORS対応**: Safari HLS用専用HTTPサーバー
- **コンテナ統合**: Docker環境での一括管理

## 実装方法

### Liquidsoap デュアルストリーミング設定
```liquidsoap
#!/usr/bin/liquidsoap

# ログ設定
set("log.file.path", "/var/log/icecast2/liquidsoap.log")
set("log.stdout", true)
set("init.allow_root", true)

# サーバー設定
set("server.telnet", true)
set("server.telnet.port", 1234)

# FLACファイルを無限ループで再生
source = playlist(mode="randomize", reload=1, "/app/programs/")
source = fallback(track_sensitive=false, [source, blank()])

# デュアル配信: OGG FLAC + ALAC
# 1. Chrome/Firefox用 OGG FLAC配信（24bit/96kHz）
output.icecast(
    %ogg(%flac(samplerate=96000, channels=2, bits_per_sample=24)),
    host="localhost",
    port=8000,
    password="hackme",
    mount="/stream.ogg",
    name="Hi-Res Radio - OGG FLAC",
    description="24bit/96kHz FLAC Stream for Chrome/Firefox",
    source
)

# 2. Safari用 ALAC配信 - FIFO経由でffmpeg処理
output.file(
    %wav(stereo=true, channels=2, samplerate=96000, samplesize=24),
    "/tmp/live.fifo",
    audio_to_stereo(source)
)
```

### ffmpeg HLS ALAC変換
```bash
# FIFO pipeからHLS ALAC配信を生成
ffmpeg -re -i /tmp/live.fifo -c:a alac -f hls \
  -hls_segment_type fmp4 -hls_time 6 -hls_list_size 5 \
  -hls_playlist_type event /var/www/html/hls/stream.m3u8
```

### CORS対応HTTPサーバー（Safari用）
```python
#!/usr/bin/env python3
import http.server
import socketserver
from http.server import SimpleHTTPRequestHandler

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range')
        super().end_headers()

    def guess_type(self, path):
        if path.endswith('.m3u8'):
            return 'application/vnd.apple.mpegurl'
        elif path.endswith('.m4s'):
            return 'video/mp4'
        return super().guess_type(path)

if __name__ == "__main__":
    PORT = 8080
    os.chdir('/var/www/html')
    with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
        httpd.serve_forever()
```

### ブラウザ検出フロントエンド
```javascript
// デュアル配信URL
const OGG_FLAC_URL = 'http://localhost:8000/stream.ogg';  // Chrome/Firefox
const HLS_ALAC_URL = 'http://localhost:8081/hls/stream.m3u8';  // Safari

function play() {
    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
    
    if (isSafari) {
        // Safari: HLS ALAC配信
        playHLSALAC();
    } else {
        // Chrome/Firefox: OGG FLAC配信
        playOggFLAC();
    }
}

function playHLSALAC() {
    audioElement = document.createElement('audio');
    
    if (audioElement.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari ネイティブHLS
        audioElement.src = HLS_ALAC_URL;
        audioElement.play();
    } else if (Hls.isSupported()) {
        // HLS.js fallback
        hls = new Hls();
        hls.loadSource(HLS_ALAC_URL);
        hls.attachMedia(audioElement);
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
            audioElement.play();
        });
    }
}

function playOggFLAC() {
    audioElement = new Audio(OGG_FLAC_URL);
    audioElement.play();
}
```

## セットアップ手順

### Docker環境構築
```bash
# 1. リポジトリクローン
git clone https://github.com/your-repo/hi_res_steaming.git
cd hi_res_steaming

# 2. FLAC音源ファイル配置
mkdir -p programs
cp your_music.flac programs/

# 3. Docker環境起動
docker-compose up -d

# 4. ストリーミング確認
echo "Chrome/Firefox: http://localhost:8000/stream.ogg"
echo "Safari: http://localhost:8081/hls/stream.m3u8"
echo "Web Interface: http://localhost:3000"
```

### Docker Compose設定
```yaml
version: '3.8'
services:
  hires-radio:
    build: .
    ports:
      - "8000:8000"      # Icecast2 OGG FLAC
      - "8081:8080"      # HLS ALAC web server
      - "1234:1234"      # Liquidsoap telnet
    volumes:
      - ./programs:/app/programs:ro
      - ./logs:/var/log/icecast2
    restart: unless-stopped

  web-server:
    image: node:18-alpine
    working_dir: /app
    ports:
      - "3000:3000"
    volumes:
      - .:/app
    command: sh -c "npm install express && node server.js"
    depends_on:
      - hires-radio
```

### 音質確認
```bash
# FLAC音源確認
ffprobe -v quiet -print_format json -show_streams programs/your_music.flac | \
  jq '.streams[0] | {sample_rate, bits_per_sample, channels, duration}'

# HLS出力確認
curl -I http://localhost:8081/hls/stream.m3u8
```

## メリット・特徴

### デュアルストリーミングの利点
- **全ブラウザ対応**: Chrome/Firefox（OGG FLAC）+ Safari（HLS ALAC）
- **音質維持**: 24bit/96kHz無劣化配信をすべてのブラウザで実現
- **同期再生**: 単一音源からの同期ライブストリーミング
- **FIFO効率**: Liquidsoap → ffmpeg リアルタイム変換による低遅延

### 技術的優位性
- **コンテナ統合**: Docker環境による一括管理・ポータビリティ
- **CORS解決**: Safari専用HTTPサーバーによるクロスオリジン対応
- **プロトコル最適化**: ブラウザ別最適配信方式の自動選択
- **開発効率**: 統一環境でのテスト・デプロイメント

### 配信品質
- **HLS最適化**: 6秒セグメント・fMP4コンテナによる安定再生
- **ALAC無劣化**: Safari環境での完全ロスレス音質
- **OGG FLAC直接**: Chrome/Firefox環境での低遅延直接再生

## 開発環境コスト

| 項目 | 費用 | 備考 |
|------|------|------|
| Docker Desktop | 無料 | 開発環境 |
| 音源ファイル | 任意 | FLAC 24bit/96kHz |
| 開発時間 | - | Docker環境自動構築 |
| **開発コスト** | **¥0** | **完全オープンソース** |

**対応ブラウザ**: Chrome, Firefox, Safari  
**配信方式**: デュアルストリーミング  
**音質**: 24bit/96kHz 無劣化配信  
**環境**: Docker統合環境