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

$tiltify_api = Faraday.new(url: "https://v5api.tiltify.com/") do |conn|
    conn.request :url_encoded
end

response = $tiltify_api.post("/oauth/token?client_id=#{$client_id}&client_secret=#{$client_secret}&grant_type=client_credentials") do |req|
    req.headers["Authorization"] = "Bearer #{$access_token}"
end

rep = JSON.parse(response.body)
$api_token = rep["access_token"]
ap rep

response = $tiltify_api.get("/api/public/campaigns/#{$campaign_id}/rewards") do |req|
    req.headers["Authorization"] = "Bearer #{$api_token}"
end
rep = JSON.parse(response.body)
ap rep