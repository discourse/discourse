require 'base64'
require 'json'

class QuandoraApi

  attr_accessor :domain, :username, :password

  def initialize(domain, username, password)
    @domain = domain
    @username = username
    @password = password
  end

  def base_url(domain)
    "https://#{domain}.quandora.com/m/json"
  end

  def auth_header(username, password)
    encoded = Base64.encode64 "#{username}:#{password}"
    { Authorization: "Basic #{encoded.strip!}" }
  end

  def list_bases_url
    "#{base_url @domain}/kb"
  end

  def list_questions_url(kb_id, limit)
    url = "#{base_url @domain}/kb/#{kb_id}/list"
    url = "#{url}?l=#{limit}" if limit
    url
  end

  def request(url)
    JSON.parse(Excon.get(url, headers: auth_header(@username, @password)))
  end

  def list_bases
    response = request list_bases_url
    response['data']
  end

  def list_questions(kb_id, limit = nil)
    url = list_questions_url(kb_id, limit)
    response = request url
    response['data']['result']
  end

  def get_question(question_id)
    url = "#{base_url @domain}/q/#{question_id}"
    response = request url
    response['data']
  end
end
