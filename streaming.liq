#!/usr/bin/liquidsoap

# ログ設定
set("log.file.path", "/var/log/icecast2/liquidsoap.log")
set("log.stdout", true)

# セキュリティ設定（Docker内でのみ使用）
set("init.allow_root", true)

# サーバー設定
set("server.telnet", true)
set("server.telnet.port", 1234)

# FLACファイルを無限ループで再生
source = playlist(mode="randomize", reload=1, "/app/programs/")

# FLACファイルが存在しない場合のフォールバック
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
    genre="Music",
    url="http://localhost:3000",
    source
)

# 2. Safari用 ALAC配信 - FIFO経由でffmpeg処理
# WAVファイルをFIFOに出力してffmpegでALAC変換
output.file(
    %wav(stereo=true, channels=2, samplerate=96000, samplesize=24),
    "/tmp/live.fifo",
    audio_to_stereo(source)
)