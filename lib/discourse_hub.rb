require_dependency 'rest_client'
require_dependency 'version'

module DiscourseHub

  class UsernameUnavailable < RuntimeError
    def initialize(username)
      @username = username
    end

    def response_message
      {
        success: false,
        message: I18n.t(
          "login.errors",
          errors:I18n.t(
            "login.not_available", suggestion: UserNameSuggester.suggest(@username)
          )
        )
      }
    end

  end

  def self.username_available?(username)
    json = get('/users/username_available', {username: username})
    [json['available'], json['suggestion']]
  end

  def self.username_match?(username, email)
    json = get('/users/username_match', {username: username, email: email})
    [json['match'], json['available'] || false, json['suggestion']]
  end

  def self.username_for_email(email)
    json = get('/users/username_match', {email: email})
    json['suggestion']
  end

  def self.register_username(username, email)
    json = post('/users', {username: username, email: email})
    if json.has_key?('success')
      true
    else
      raise UsernameUnavailable.new(username)  # TODO: report ALL the errors
    end
  end

  def self.unregister_username(username)
    json = delete('/memberships/' + username)
    json.has_key?('success')
  end

  def self.change_username(current_username, new_username)
    json = put("/users/#{current_username}/username", {username: new_username})
    if json.has_key?('success')
      true
    else
      raise UsernameUnavailable.new(new_username)  # TODO: report ALL the errors
    end
  end

  def self.version_check_payload
    {
      installed_version: Discourse::VERSION::STRING,
      forum_title: SiteSetting.title,
      forum_description: SiteSetting.site_description,
      forum_url: Discourse.base_url,
      contact_email: SiteSetting.contact_email,
      topic_count: Topic.listable_topics.count,
      post_count: Post.count,
      user_count: User.count,
      topics_7_days: Topic.listable_topics.where('created_at > ?', 7.days.ago).count,
      posts_7_days: Post.where('created_at > ?', 7.days.ago).count,
      users_7_days: User.where('created_at > ?', 7.days.ago).count,
      login_required: SiteSetting.login_required,
      locale: SiteSetting.default_locale
    }
  end


  def self.discourse_version_check
    get('/version_check', version_check_payload)
  end


  private

  def self.get(rel_url, params={})
    singular_action :get, rel_url, params
  end

  def self.post(rel_url, params={})
    collection_action :post, rel_url, params
  end

  def self.put(rel_url, params={})
    collection_action :put, rel_url, params
  end

  def self.delete(rel_url, params={})
    singular_action :delete, rel_url, params
  end

  def self.singular_action(action, rel_url, params={})
    JSON.parse RestClient.send(action, "#{hub_base_url}#{rel_url}", {params: {access_token: access_token}.merge(params), accept: accepts } )
  end

  def self.collection_action(action, rel_url, params={})
    JSON.parse RestClient.send(action, "#{hub_base_url}#{rel_url}", {access_token: access_token}.merge(params), content_type: :json, accept: accepts )
  end

  def self.hub_base_url
    if Rails.env == 'production'
      'http://api.discourse.org/api'
    else
      ENV['HUB_BASE_URL'] || 'http://local.hub:3000/api'
    end
  end

  def self.access_token
    SiteSetting.discourse_org_access_key
  end

  def self.accepts
    [:json, 'application/vnd.discoursehub.v1']
  end

  def self.username_operation
    if SiteSetting.call_discourse_hub?
      begin
        yield
      rescue DiscourseHub::UsernameUnavailable
        false
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end
  end
end
