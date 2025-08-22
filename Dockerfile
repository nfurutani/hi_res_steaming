FROM ubuntu:22.04

# 非インタラクティブモードでパッケージインストール
ENV DEBIAN_FRONTEND=noninteractive

# システム更新とパッケージインストール
RUN apt-get update && apt-get install -y \
    icecast2 \
    liquidsoap \
    ffmpeg \
    python3 \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 非rootユーザー作成とHLSディレクトリ作成
RUN useradd -m -s /bin/bash radio && \
    mkdir -p /etc/icecast2 /var/log/icecast2 /app/programs /var/www/html/hls && \
    chown -R radio:radio /var/log/icecast2 /app /var/www/html/hls

# 作業ディレクトリ作成
WORKDIR /app

# Icecast2設定ファイルをコピー
COPY icecast.xml /etc/icecast2/icecast.xml

# Liquidsoap設定ファイルをコピー
COPY streaming.liq /app/streaming.liq

# CORS対応HTTPサーバーをコピー
COPY cors_server.py /app/cors_server.py

# 設定ファイルの権限調整
RUN chown radio:radio /app/streaming.liq

# programsディレクトリをマウントポイントとして使用
VOLUME ["/app/programs"]

# ポート公開
EXPOSE 8000 8080 1234

# 起動スクリプト作成
RUN echo '#!/bin/bash\n\
echo "🎵 Starting Hi-Res Radio Dual Streaming Container..."\n\
echo "Checking for FLAC files..."\n\
if [ -z "$(find /app/programs -name '*.flac' 2>/dev/null)" ]; then\n\
    echo "⚠️  No FLAC files found in /app/programs/"\n\
    echo "Please mount your FLAC files to /app/programs volume"\n\
    exit 1\n\
fi\n\
\n\
echo "🌐 Starting Icecast2..."\n\
icecast2 -c /etc/icecast2/icecast.xml &\n\
ICECAST_PID=$!\n\
\n\
echo "🌐 Starting CORS-enabled HLS Web Server for Safari..."\n\
cd /var/www/html && python3 /app/cors_server.py &\n\
WEB_PID=$!\n\
\n\
echo "🎵 Creating FIFO pipe for ALAC..."\n\
rm -f /tmp/live.fifo\n\
mkfifo /tmp/live.fifo\n\
\n\
echo "🍎 Starting ffmpeg HLS ALAC converter for Safari..."\n\
ffmpeg -re -i /tmp/live.fifo -c:a alac -f hls \\\n\
  -hls_segment_type fmp4 -hls_time 6 -hls_list_size 5 \\\n\
  -hls_playlist_type event /var/www/html/hls/stream.m3u8 2>/dev/null &\n\
FFMPEG_PID=$!\n\
\n\
sleep 5\n\
\n\
echo "🎵 Starting Liquidsoap dual streaming..."\n\
liquidsoap /app/streaming.liq &\n\
LIQUIDSOAP_PID=$!\n\
\n\
echo ""\n\
echo "🎉 Hi-Res Radio Dual Streaming is active!"\n\
echo "🌐 Chrome/Firefox: http://localhost:8000/stream.ogg (OGG FLAC)"\n\
echo "🍎 Safari: http://localhost:8081/hls/stream.m3u8 (HLS ALAC)"\n\
echo "📊 Icecast Admin: http://localhost:8000/admin/"\n\
echo ""\n\
\n\
# プロセス監視とシグナル処理\n\
trap '\''echo "Stopping services..."; kill $ICECAST_PID $WEB_PID $FFMPEG_PID $LIQUIDSOAP_PID 2>/dev/null; rm -f /tmp/live.fifo; exit 0'\'' INT TERM\n\
\n\
wait\n\
' > /app/start.sh && chmod +x /app/start.sh && chown radio:radio /app/start.sh

# radioユーザーに切り替え
USER radio

# 起動コマンド
CMD ["/app/start.sh"]