const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

// Static files
app.use(express.static('.'));

// Serve FLAC file with proper headers
app.get('/flac', (req, res) => {
    const flacPath = path.join(__dirname, 'programs/main_program.flac');
    
    if (!fs.existsSync(flacPath)) {
        return res.status(404).send('FLAC file not found');
    }

    const stat = fs.statSync(flacPath);
    const fileSize = stat.size;
    const range = req.headers.range;

    // Support range requests for streaming
    if (range) {
        const parts = range.replace(/bytes=/, "").split("-");
        const start = parseInt(parts[0], 10);
        const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
        const chunksize = (end - start) + 1;
        const file = fs.createReadStream(flacPath, { start, end });
        
        res.writeHead(206, {
            'Content-Range': `bytes ${start}-${end}/${fileSize}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunksize,
            'Content-Type': 'audio/flac',
        });
        file.pipe(res);
    } else {
        res.writeHead(200, {
            'Content-Length': fileSize,
            'Content-Type': 'audio/flac',
            'Accept-Ranges': 'bytes',
        });
        fs.createReadStream(flacPath).pipe(res);
    }
});

app.listen(PORT, () => {
    console.log(`🎵 FLAC Player: http://localhost:${PORT}`);
});