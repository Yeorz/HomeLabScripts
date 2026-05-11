'use strict';

// Matrix rain canvas — used on the Work listing header
const canvas = document.getElementById('matrix-canvas');
if (!canvas) throw new Error('no canvas');

const ctx = canvas.getContext('2d');
const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%^&*(){}[]<>/\\|';
const fontSize = 13;
let cols, drops;

function resize() {
    canvas.width  = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
    cols  = Math.floor(canvas.width / fontSize);
    drops = Array(cols).fill(1);
}

function draw() {
    ctx.fillStyle = 'rgba(5, 9, 5, 0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#00ff41';
    ctx.font = fontSize + 'px "JetBrains Mono", monospace';

    for (let i = 0; i < drops.length; i++) {
        const char = chars[Math.floor(Math.random() * chars.length)];
        ctx.fillText(char, i * fontSize, drops[i] * fontSize);
        if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) drops[i] = 0;
        drops[i]++;
    }
}

resize();
window.addEventListener('resize', resize);
setInterval(draw, 45);
