require_dependency 'rest_client'
require_dependency 'version'

module DiscourseHub

  class NicknameUnavailable < RuntimeError; end

  def self.nickname_available?(nickname)
    response = get('/users/nickname_available', {nickname: nickname})
    [response['available'], response['suggestion']]
  end

  def self.nickname_match?(nickname, email)
    response = get('/users/nickname_match', {nickname: nickname, email: email})
    [response['match'], response['available'] || false, response['suggestion']]
  end

  def self.register_nickname(nickname, email)
    json = post('/users', {nickname: nickname, email: email})
    if json.has_key?('success')
      true
    else
      raise NicknameUnavailable  # TODO: report ALL the errors
    end
  end

  def self.change_nickname(current_nickname, new_nickname)
    json = put("/users/#{current_nickname}/nickname", {nickname: new_nickname})
    if json.has_key?('success')
      true
    else
      raise NicknameUnavailable  # TODO: report ALL the errors
    end
  end


  def self.discourse_version_check
    get('/version_check', {
      installed_version: Discourse::VERSION::STRING,
      forum_title: SiteSetting.title,
      forum_domain: Discourse.current_hostname
    })
  end


  private

  def self.get(rel_url, params={})
    response = RestClient.get( "#{hub_base_url}#{rel_url}", {params: {access_token: access_token}.merge(params), accept: accepts } )
    JSON.parse(response)
  end

  def self.post(rel_url, params={})
    response = RestClient.post( "#{hub_base_url}#{rel_url}", {access_token: access_token}.merge(params), content_type: :json, accept: accepts )
    JSON.parse(response)
  end

  def self.put(rel_url, params={})
    response = RestClient.put( "#{hub_base_url}#{rel_url}", {access_token: access_token}.merge(params), content_type: :json, accept: accepts )
    JSON.parse(response)
  end

  def self.hub_base_url
    if Rails.env == 'production'
      'http://api.discourse.org/api'
    else
      'http://local.hub:3000/api'
    end
  end

  def self.access_token
    SiteSetting.discourse_org_access_key
  end

  def self.accepts
    [:json, 'application/vnd.discoursehub.v1']
  end
end