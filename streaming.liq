#!/usr/bin/liquidsoap

# ログ設定
settings.log.file.path.set("/var/log/icecast2/liquidsoap.log")
settings.log.stdout.set(true)

# セキュリティ設定（Docker内でのみ使用）
settings.init.allow_root.set(true)

# サーバー設定
settings.server.telnet.set(true)
settings.server.telnet.port.set(1234)
settings.server.telnet.bind_addr.set("0.0.0.0")

# FLACファイルを順番再生（プレイリストファイル使用）
source = playlist(mode="normal", "/app/playlist.m3u")

# mksafe()でfallibleソースを安全にする
source = mksafe(source)


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