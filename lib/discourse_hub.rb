require_dependency 'rest_client'
require_dependency 'version'

module DiscourseHub

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
    JSON.parse RestClient.send(action, "#{hub_base_url}#{rel_url}", {params: params, accept: accepts } )
  end

  def self.collection_action(action, rel_url, params={})
    JSON.parse RestClient.send(action, "#{hub_base_url}#{rel_url}", params, content_type: :json, accept: accepts )
  end

  def self.hub_base_url
    if Rails.env == 'production'
      'http://api.discourse.org/api'
    else
      ENV['HUB_BASE_URL'] || 'http://local.hub:3000/api'
    end
  end

  def self.accepts
    [:json, 'application/vnd.discoursehub.v1']
  end

end
