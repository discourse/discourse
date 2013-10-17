# A class we can use to serialize the site data
require_dependency 'score_calculator'
require_dependency 'trust_level'

class Site
  include ActiveModel::Serialization

  def initialize(guardian)
    @guardian = guardian
  end

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

  def group_names
    @group_name ||= Group.pluck(:name)
  end

  def categories
    @categories ||= begin
      categories = Category
        .secured(@guardian)
        .latest
        .includes(:topic_only_relative_url).to_a

      allowed_topic_create = Set.new(Category.topic_create_allowed(@guardian).pluck(:id))

      categories.each do |category|
        category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create.include?(category.id)
      end
      categories
    end
  end

  def archetypes
    Archetype.list.reject { |t| t.id == Archetype.private_message }
  end

  def cache_key
    k = "site_json_cats_"
    k << @guardian.secure_category_ids.join("_") if @guardian
  end

  def self.cached_json(guardian)

    if guardian.anonymous? && SiteSetting.login_required
      return {}.to_json
    end

    # Sam: bumping this way down, SiteSerializer will serialize post actions as well,
    #   On my local this was not being flushed as post actions types changed, it turn this
    #   broke local.
    site = Site.new(guardian)
    #Discourse.cache.fetch(site.cache_key, family: "site", expires_in: 1.minute) do
    MultiJson.dump(SiteSerializer.new(site, root: false))
    #end
  end

  def self.invalidate_cache
    Discourse.cache.delete_by_family("site")
  end
end
