socket = new WebSocket("ws://192.168.0.16:5963");
var connected = false;
var showing = false;

socket.onopen = function (event) {
    connected = true;
}

socket.onmessage = function (event) {
    var data = JSON.parse(event.data);
    if (data.to == "spotifyOverlay"){
        var msg = data.payload;
        if (msg.type === "song"){
            updateOverlay(msg);
            updateProgress(msg.progress_ms, msg.duration_ms);
            const overlay = document.getElementById("overlay");
            if (showing === false){
                overlay.style.transform = "translateY(0)";
                showing = true
                setTimeout(moveUp, 10000);
            }
            
        }
        else if (msg.type === "progress"){
            updateProgress(msg.progress_ms, msg.duration_ms);
        }
        else if (msg.type === "show"){
            const overlay = document.getElementById("overlay");
            if (showing === false){
                overlay.style.transform = "translateY(0)";
                showing = true
                setTimeout(moveUp, 10000);
            }
        }
    }
    
}

socket.onclose = function (event) {
    connected = false;
}


function moveUp(){
    const overlay = document.getElementById("overlay");
    overlay.style.transform = "translateY(-100%)";
    showing = false;
}

function updateOverlay(data){
    const overlay = document.getElementById("overlay");
    const title = document.getElementById("title");
    const artist = document.getElementById("artist");
    const image = document.getElementById("image");
    title.innerText = data.name;
    artist.innerText = data.artist;
    image.src = data.image;
    updateBackgroudColor(data.image);
}

function updateProgress(progress, duration){
    const progressBar = document.getElementById("progressBar");
    var width = (progress / duration) * 300;
    progressBar.style.width = width + "px";
}

function updateBackgroudColor(imageUrl){
    const overlay = document.getElementById("overlay");
    const image = new Image();
    image.crossOrigin = "Anonymous";
    image.onload = function() {
        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");
        context.drawImage(image, 0, 0);
    
        const imageData = context.getImageData(0, 0, image.width, image.height);
        const data = imageData.data;
    
        let red = 0;
        let green = 0;
        let blue = 0;
    
        for (let i = 0; i < data.length; i += 4) {
            red += data[i];
            green += data[i + 1];
            blue += data[i + 2];
        }
        const pixelCount = data.length / 4;
        const averageRed = Math.round((red / pixelCount));
        const averageGreen = Math.round((green / pixelCount));
        const averageBlue = Math.round((blue / pixelCount));

        const averageColors = (averageRed + averageGreen + averageBlue) / 3;
        const diffRed = (averageRed - averageColors) * 4;
        const diffGreen = (averageGreen - averageColors) * 4;
        const diffBlue = (averageBlue - averageColors) * 4;

        const averageColor = `rgb(${145 + diffRed}, ${145 + diffGreen}, ${145 + diffBlue})`;

        overlay.style.backgroundColor = averageColor;
    };
    
    image.src = imageUrl;
}

setInterval(function(){
    if (!connected){
        socket = new WebSocket("ws://192.168.0.16:5963");
    }
}, 100000);