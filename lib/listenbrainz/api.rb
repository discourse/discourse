# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Listenbrainz
  class Api
    def self.artist(mbid)
      uri = URI.parse("https://listenbrainz.org/artist/#{mbid}/")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = 'application/json'

      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end