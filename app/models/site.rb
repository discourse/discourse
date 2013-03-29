# A class we can use to serialize the site data
require_dependency 'score_calculator'
require_dependency 'trust_level'

class Site
  include ActiveModel::Serialization

  def site_setting
    SiteSetting
  end

  def post_action_types
    PostActionType.ordered
  end

  def notification_types
    Notification.types
  end

  def trust_levels
    TrustLevel.all
  end

  def categories
    Category.latest.includes(:topic_only_relative_url)
  end

  def archetypes
    Archetype.list.reject { |t| t.id == Archetype.private_message }
  end

  def self.cache_key
    "site_json"
  end

  def self.cached_json
    # Sam: bumping this way down, SiteSerializer will serialize post actions as well,
    #   On my local this was not being flushed as post actions types changed, it turn this
    #   broke local.
    Rails.cache.fetch(Site.cache_key, expires_in: 1.minute) do
      MultiJson.dump(SiteSerializer.new(Site.new, root: false))
    end
  end

  def self.invalidate_cache
    Rails.cache.delete(Site.cache_key)
  end
end
