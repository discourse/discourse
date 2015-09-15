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

  def topic_flag_types
    post_action_types.where(name_key: ['inappropriate', 'spam', 'notify_moderators'])
  end

  def notification_types
    Notification.types
  end

  def trust_levels
    TrustLevel.all
  end

  def groups
    @groups ||= Group.order(:name).map { |g| { id: g.id, name: g.name } }
  end

  def user_fields
    UserField.all
  end

  def categories
    @categories ||= begin
      categories = Category
        .secured(@guardian)
        .includes(:topic_only_relative_url, :subcategories)
        .order(:position)

      unless SiteSetting.allow_uncategorized_topics
        categories = categories.where('categories.id <> ?', SiteSetting.uncategorized_category_id)
      end

      categories = categories.to_a

      allowed_topic_create = Set.new(Category.topic_create_allowed(@guardian).pluck(:id))

      by_id = {}

      category_user = {}
      unless @guardian.anonymous?
        category_user = Hash[*CategoryUser.where(user: @guardian.user).pluck(:category_id, :notification_level).flatten]
      end

      categories.each do |category|
        category.notification_level = category_user[category.id]
        category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create.include?(category.id)
        category.has_children = category.subcategories.present?
        by_id[category.id] = category
      end

      categories.reject! { |c| c.parent_category_id && !by_id[c.parent_category_id] }
      categories
    end
  end

  def suppressed_from_homepage_category_ids
    categories.select { |c| c.suppress_from_homepage == true }.map(&:id)
  end

  def archetypes
    Archetype.list.reject { |t| t.id == Archetype.private_message }
  end

  def self.json_for(guardian)

    if guardian.anonymous? && SiteSetting.login_required
      return {
        periods: TopTopic.periods.map(&:to_s),
        filters: Discourse.filters.map(&:to_s),
        user_fields: UserField.all.map do |userfield|
          UserFieldSerializer.new(userfield, root: false, scope: guardian)
        end
      }.to_json
    end

    site = Site.new(guardian)
    MultiJson.dump(SiteSerializer.new(site, root: false, scope: guardian))
  end

end
