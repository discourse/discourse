# frozen_string_literal: true

require 'base64'
require 'json'

class SocialcastApi

  attr_accessor :domain, :username, :password

  def initialize(domain, username, password)
    @domain = domain
    @username = username
    @password = password
  end

  def base_url
    "https://#{@domain}.socialcast.com/api"
  end

  def headers
    encoded = Base64.encode64 "#{@username}:#{@password}"
    { Authorization: "Basic #{encoded.strip!}", Accept: "application/json" }
  end

  def request(url)
    JSON.parse(Excon.get(url, headers: headers))
  end

  def list_users(opts = {})
    page = opts[:page] ? opts[:page] : 1
    response = request "#{base_url}/users?page=#{page}"
    response['users'].sort { |u| u['id'] }
  end

  def list_messages(opts = {})
    page = opts[:page] ? opts[:page] : 1
    response = request "#{base_url}/messages?page=#{page}"
    response['messages'].sort { |m| m['id'] }
  end
end
