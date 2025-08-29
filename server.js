const express = require('express');
const path = require('path');
const net = require('net');

const app = express();
const PORT = process.env.PORT || 3000;

// 静的ファイル配信（index.html, assets等）
app.use(express.static('.'));

// Now Playing API - Liquidsoap telnet から現在再生中の曲情報を取得
app.get('/api/nowplaying', async (req, res) => {
    try {
        const nowPlaying = await getLiquidsoapNowPlaying();
        res.json(nowPlaying);
    } catch (error) {
        console.error('Failed to get now playing:', error);
        res.status(500).json({ error: 'Failed to get now playing info' });
    }
});

// Liquidsoap telnet接続で現在再生情報を取得
function getLiquidsoapNowPlaying() {
    return new Promise((resolve, reject) => {
        const client = new net.Socket();
        let response = '';
        
        client.connect(1234, 'hires-radio-streaming', () => {
            client.write('request.on_air\n');
        });
        
        client.on('data', (data) => {
            response += data.toString();
            if (response.includes('END')) {
                const requestId = response.split('\n')[0].trim();
                if (requestId && requestId !== 'END') {
                    // メタデータ取得
                    client.write(`request.metadata ${requestId}\n`);
                } else {
                    client.destroy();
                    resolve({ title: 'No track playing', artist: '', album: '' });
                }
            }
            
            if (response.includes('title=')) {
                client.destroy();
                const metadata = parseMetadata(response);
                resolve(metadata);
            }
        });
        
        client.on('error', (err) => {
            reject(err);
        });
        
        client.setTimeout(5000, () => {
            client.destroy();
            reject(new Error('Timeout'));
        });
    });
}

// メタデータレスポンスをパース
function parseMetadata(response) {
    const lines = response.split('\n');
    const metadata = {};
    
    lines.forEach(line => {
        const match = line.match(/^(\w+)="([^"]*)"$/);
        if (match) {
            metadata[match[1]] = match[2];
        }
    });
    
    return {
        title: metadata.title || 'Unknown',
        artist: metadata.artist || 'Unknown Artist',
        album: metadata.album || 'Unknown Album',
        filename: metadata.filename || '',
        status: metadata.status || 'unknown'
    };
}

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