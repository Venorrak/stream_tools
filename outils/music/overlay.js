socket = new WebSocket("ws://172.31.232.73:5962");

socket.onmessage = function (event) {
    var data = JSON.parse(event.data);
    console.log(data);
    // data = {
    //     "name" => playback["item"]["name"],
    //     "artist" => playback["item"]["artists"][0]["name"],
    //     "image" => playback["item"]["album"]["images"][0]["url"],
    //     "progress_ms" => playback["progress_ms"],
    //     "duration_ms" => playback["item"]["duration_ms"]
    // }
    const overlay = document.getElementById("overlay");
    const title = document.getElementById("title");
    const artist = document.getElementById("artist");
    const image = document.getElementById("image");
    console.log(data.name);
    title.innerText = data.name;
    artist.innerText = data.artist;
    image.src = data.image;
    var progress = (data.progress_ms * 100) / data.duration_ms;

}