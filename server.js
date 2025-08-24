const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// 静的ファイル配信（index.html, assets等）
app.use(express.static('.'));

// ルートアクセス時にindex.htmlを返す
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// サーバー起動
app.listen(PORT, () => {
    console.log(`🎵 Hi-Res Streaming Web Interface`);
    console.log(`📡 Server running at http://localhost:${PORT}`);
    console.log(`🎧 OGG FLAC Stream: http://localhost:8000/stream.ogg`);
    console.log(`🍎 HLS ALAC Stream: http://localhost:8081/hls/stream.m3u8`);
});