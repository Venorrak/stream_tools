socket = new WebSocket("ws://172.28.230.54:5962");
var connected = false;

socket.onopen = function (event) {
    connected = true;
}

socket.onmessage = function (event) {
    var data = JSON.parse(event.data);
    if (data.type === "song"){
        updateOverlay(data);
        updateProgress(data.progress_ms, data.duration_ms);
        const overlay = document.getElementById("overlay");
        overlay.style.transform = "translateY(0)";
        setTimeout(moveUp, 5000);
    }
    else if (data.type === "progress"){
        updateProgress(data.progress_ms, data.duration_ms);
    }
    else if (data.type === "show"){
        const overlay = document.getElementById("overlay");
        overlay.style.transform = "translateY(0)";
        setTimeout(moveUp, 5000);
    }
}

socket.onclose = function (event) {
    connected = false;
}


function moveUp(){
    const overlay = document.getElementById("overlay");
    overlay.style.transform = "translateY(-100%)";
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
        socket = new WebSocket("ws://172.28.230.54:5962");
    }
}, 100000);