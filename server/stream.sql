DROP DATABASE IF EXISTS stream;
CREATE DATABASE stream;

CREATE USER IF NOT EXISTS 'bus'@'localhost' IDENTIFIED BY '1234';
GRANT ALL ON *.* TO 'bus'@'localhost';

USE stream;

CREATE TABLE IF NOT EXISTS users(
    id INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    twitch_id VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS points(
    id INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    points INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS lore(
    id INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    word VARCHAR(255) NOT NULL,
    count INT NOT NULL
);