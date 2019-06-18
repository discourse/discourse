# frozen_string_literal: true

require 'json'
require 'cgi'
require 'time'

class SocialcastUser

  def initialize(user_json)
    @parsed_json = JSON.parse user_json
  end

  def user
    email = @parsed_json['contact_info']['email']
    email = "#{@parsed_json['id']}@noemail.com" unless email

    user = {}
    user[:id] = @parsed_json['id']
    user[:name] = @parsed_json['name']
    user[:username] = @parsed_json['username']
    user[:email] = email
    user[:staged] = true
    user
  end

end
