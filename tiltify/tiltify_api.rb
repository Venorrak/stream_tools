require "bundler/inline"
require "json"
require "awesome_print"

gemfile do
    source "https://rubygems.org"
    gem "faraday"
end

require "faraday"
require_relative "secret.rb"

$api_token = ""
$refresh_token = ""

$tiltify_api = Faraday.new(url: "https://v5api.tiltify.com/") do |conn|
    conn.request :url_encoded
end


get '/tiltify/activate' do
    if request.ip == @my_ip
        response = $tiltify_api.get("/oauth/authorize?client_id=#{$client_id}&response_type=code&redirect_uri=https://server.venorrak.dev/tiltify/code") do |req|
            req.headers["Authorization"] = "Bearer #{$access_token}"
        end
        return [
            307,
            { "Location" => response.headers["location"]},
            ""
        ]
    end
end 

get '/tiltify/code' do
    if request.ip == @my_ip
        code = params[:code]
        if code != nil
            response = $tiltify_api.post("/oauth/token?client_id=#{$client_id}&client_secret=#{$client_secret}&grant_type=authorization_code&code=#{code}&redirect_uri=https://server.venorrak.dev/tiltify/code") do |req|
                req.headers["Authorization"] = "Bearer #{$access_token}"
            end
            begin
                rep = JSON.parse(response.body)
                $api_token = rep["access_token"]
                $refresh_token = rep["refresh_token"]
                p "got both tokens"
            rescue
                p "continue"
            end
        else
            rep = JSON.parse(response.body)
            $api_token = rep["access_token"]
            $refresh_token = rep["refresh_token"]
            p "got both tokens"
        end
    end
end


get '/tiltify/rewards' do
    if request.env["HTTP_AUTHORIZATION"] == "prodIsAwesome"
        response = $tiltify_api.get("/api/public/campaigns/#{$campaign_id}/rewards") do |req|
            req.headers["Authorization"] = "Bearer #{$api_token}"
        end
        return response.body
    end
end

def refresh_token()
    p $refresh_token
    response = $tiltify_api.post("/oauth/token?client_id=#{$client_id}&client_secret=#{$client_secret}&grant_type=refresh_token&refresh_token=#{$refresh_token}") do |req|
        req.headers["Authorization"] = "Bearer #{$access_token}"
    end
    rep = JSON.parse(response.body)
    $api_token = rep["access_token"]
    $refresh_token = rep["refresh_token"]
end

Thread.start do 
    loop do
        sleep(7100)
        refresh_token()
        p "refreshed token"
    end
end