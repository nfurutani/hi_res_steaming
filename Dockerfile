FROM ubuntu:22.04

# 非インタラクティブモードでパッケージインストール
ENV DEBIAN_FRONTEND=noninteractive

# システム更新とパッケージインストール
RUN apt-get update && apt-get install -y \
    icecast2 \
    liquidsoap \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 非rootユーザー作成
RUN useradd -m -s /bin/bash radio && \
    mkdir -p /etc/icecast2 /var/log/icecast2 /app/programs && \
    chown -R radio:radio /var/log/icecast2 /app

# 作業ディレクトリ作成
WORKDIR /app

# Icecast2設定ファイルをコピー
COPY icecast.xml /etc/icecast2/icecast.xml

# Liquidsoap設定ファイルをコピー
COPY streaming.liq /app/streaming.liq

# 設定ファイルの権限調整
RUN chown radio:radio /app/streaming.liq

# programsディレクトリをマウントポイントとして使用
VOLUME ["/app/programs"]

# ポート公開
EXPOSE 8000 1234

# 起動スクリプト作成
RUN echo '#!/bin/bash\n\
echo "🎵 Starting Hi-Res Radio Docker Container..."\n\
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
sleep 5\n\
\n\
echo "🎵 Starting Liquidsoap..."\n\
liquidsoap /app/streaming.liq &\n\
LIQUIDSOAP_PID=$!\n\
\n\
echo ""\n\
echo "🎉 Hi-Res Radio is streaming!"\n\
echo "📻 Stream URL: http://localhost:8000/stream.ogg"\n\
echo "📊 Icecast Admin: http://localhost:8000/admin/"\n\
echo ""\n\
\n\
# プロセス監視とシグナル処理\n\
trap '\''echo "Stopping services..."; kill $ICECAST_PID $LIQUIDSOAP_PID 2>/dev/null; exit 0'\'' INT TERM\n\
\n\
wait\n\
' > /app/start.sh && chmod +x /app/start.sh && chown radio:radio /app/start.sh

# radioユーザーに切り替え
USER radio

# 起動コマンド
CMD ["/app/start.sh"]