require "bundler/inline"
require "json"
require "socket"
require "date"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "base64"
require "digest"
require "securerandom"
require 'timeout'

gemfile do
    source "https://rubygems.org"
    gem "faraday"
end

require "faraday"
require_relative "secret.rb"
require_relative "godot_cli.rb"
require_relative "chat_tracker.rb"
require_relative "obs_cli.rb"

godot_init()

def main_menu()
    system "clear"
    puts "1. godot"
    puts "2. twitch"
    puts "3. obs"
    puts "4. exit"
    print "Enter your choice: "
    choice = gets.chomp.to_i
    case choice
    when 1
        godot_menu()
    when 2
        twitch_menu()
    when 3
        obs_menu()
    when 4
        exit
    else
        puts "Invalid choice"
        sleep 1
        main_menu()
    end
end

main_menu()