class MusicApi
    @password = nil

    @api = nil

    def initialize(password)
        @password = password
        @api = Faraday.new(url: "https://music.venorrak.dev") do |conn|
            conn.request :url_encoded
        end
    end

    def getPlaybackState()
        begin
            pass, salt = generateSaltedPass()
            response = @api.get("/rest/getNowPlaying?u=venorrak&v=1.16.1&c=test&t=#{pass}&f=json&s=#{salt}")
            if response.status == 200
                rep = JSON.parse(response.body)
                return rep["subsonic-response"]["nowPlaying"]
            else
                return nil
            end
        rescue
            return nil
        end
    end

    def generateSaltedPass()
        salt = rand(36**6).to_s(36)
        return Digest::MD5.hexdigest(@password + salt), salt
    end
end