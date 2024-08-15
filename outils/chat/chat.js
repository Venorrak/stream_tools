socket = new WebSocket("ws://192.168.0.16:5963");

var data;

function build_message(data){
    var text = "";
    for (var i = 0; i < data.length; i++){
        if (data[i].type == 'text'){
            text += purifyString(data[i].content);
        } else if (data[i].type == 'emote'){
            text += `<img src="https://static-cdn.jtvnw.net/emoticons/v2/${data[i].id}/static/light/1.0" alt="" class="emote">`;
        }
    }  
    return text;
}

function sound_raid(){
    var audio = new Audio('sounds/raid.mp3');
    audio.volume = 0.7;
    audio.play();
}

function sound_alert(){
    var audio = new Audio('sounds/yay.mp3');
    audio.volume = 0.7;
    audio.play();
}

function sound_ad(){
    var audio = new Audio('sounds/ads.mp3');
    audio.volume = 0.4;
    audio.play();
}

function sound_message(){
    var audio = new Audio('sounds/message2.mp3');
    audio.volume = 0.1;
    audio.play();
}

function purifyString(string) {
    return string.replace(/<[^>]+>/g, '');
}

socket.onopen = function(event){
    console.log('Connected to chat');
}

socket.onmessage = function(event){
    var data = JSON.parse(event.data);
    console.log(data);
    if (data.to == "chat"){
        var chat = document.getElementById('chat');
        var message = document.createElement('div');
        message.className = 'message';
        sound_message();
        switch (data.payload.type){
            case 'notif':
                message.classList.add('notif')
                sound_alert();
                break;
            case 'negatif':
                message.classList.add('negatif')
                sound_ad();
                break;
            case 'subscribe':
                message.classList.add('subscibe')
                sound_alert();
                break;
            case 'cheer':
                message.classList.add('cheer')
                sound_alert();
                break;
            case 'raid':
                message.classList.add('raid')
                sound_raid();
                break;
        }
        var name = document.createElement('div');
        name.className = 'name';
        var nameH1 = document.createElement('h2');
        nameH1.innerHTML = purifyString(data.payload.name)
        nameH1.style.color = data.payload.name_color;
        var nameImg = document.createElement('img');
        nameImg.src = data.payload.profile_image_url;
        nameImg.alt = '';
        nameImg.className = 'profile';
        name.appendChild(nameImg);
        name.appendChild(nameH1);
        var dataDiv = document.createElement('div');
        dataDiv.className = 'data';
        var dataP = document.createElement('p');
        var line = document.createElement('hr');

        dataP.innerHTML = build_message(data.payload.message);

        dataDiv.appendChild(dataP);
        message.appendChild(name);
        message.appendChild(line);
        message.appendChild(dataDiv);

        message.style.visibility = 'hidden';

        chat.insertBefore(message, chat.firstChild);
        var messageHeight = message.offsetHeight;
        chat.removeChild(message);
        message.style.visibility = 'visible'; 
        
        var existingMessages = chat.getElementsByClassName('message');
        Array.from(existingMessages).forEach(function(existingMessage) {
            existingMessage.style.transition = 'transform 0.5s';
            existingMessage.style.transform = `translateY(${messageHeight / 2}px)`;
        });

        message.style.opacity = '0';
        message.style.transform = 'translateX(100%)';
        chat.insertBefore(message, chat.firstChild);

        setTimeout(function(){
            message.style.transition = 'opacity 0.5s, transform 0.5s';
            message.style.opacity = '1';
            message.style.transform = 'translateY(0)';
        }, 10);

        setTimeout(function() {
            Array.from(existingMessages).forEach(function(existingMessage) {
                existingMessage.style.transition = 'transform 0.5s';
                existingMessage.style.transform = 'translateY(0)';
            });
        }, 100);
    }
}