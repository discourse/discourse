# frozen_string_literal: true

# A class we can use to serialize the site data
require_dependency 'score_calculator'
require_dependency 'trust_level'

class Site
  include ActiveModel::Serialization

  cattr_accessor :preloaded_category_custom_fields
  self.preloaded_category_custom_fields = Set.new

  def initialize(guardian)
    @guardian = guardian
    Category.preload_custom_fields(categories, preloaded_category_custom_fields) if preloaded_category_custom_fields.present?
  end

  def site_setting
    SiteSetting
  end

  def notification_types
    Notification.types
  end

  def trust_levels
    TrustLevel.all
  end

  def user_fields
    UserField.all
  end

  def categories
    @categories ||= begin
      categories = Category
        .includes(:uploaded_logo, :uploaded_background, :tags, :tag_groups)
        .secured(@guardian)
        .joins('LEFT JOIN topics t on t.id = categories.topic_id')
        .select('categories.*, t.slug topic_slug')
        .order(:position)

      categories = categories.to_a

      with_children = Set.new
      categories.each do |c|
        if c.parent_category_id
          with_children << c.parent_category_id
        end
      end

      allowed_topic_create = nil
      unless @guardian.is_admin?
        allowed_topic_create_ids =
          @guardian.anonymous? ? [] : Category.topic_create_allowed(@guardian).pluck(:id)
        allowed_topic_create = Set.new(allowed_topic_create_ids)
      end

      by_id = {}

      category_user = {}
      unless @guardian.anonymous?
        category_user = Hash[*CategoryUser.where(user: @guardian.user).pluck(:category_id, :notification_level).flatten]
      end

      regular = CategoryUser.notification_levels[:regular]

      categories.each do |category|
        category.notification_level = category_user[category.id] || regular
        category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create&.include?(category.id) || @guardian.is_admin?
        category.has_children = with_children.include?(category.id)
        by_id[category.id] = category
      end

      categories.reject! { |c| c.parent_category_id && !by_id[c.parent_category_id] }
      categories
    end
  end

  def groups
    Group.visible_groups(@guardian.user, "name ASC", include_everyone: true)
  end

  def suppressed_from_latest_category_ids
    categories.select { |c| c.suppress_from_latest == true }.map(&:id)
  end

  def archetypes
    Archetype.list.reject { |t| t.id == Archetype.private_message }
  end

  def auth_providers
    Discourse.enabled_auth_providers
  end

  def self.json_for(guardian)

    if guardian.anonymous? && SiteSetting.login_required
      return {
        periods: TopTopic.periods.map(&:to_s),
        filters: Discourse.filters.map(&:to_s),
        user_fields: UserField.all.map do |userfield|
          UserFieldSerializer.new(userfield, root: false, scope: guardian)
        end,
        auth_providers: Discourse.enabled_auth_providers.map do |provider|
          AuthProviderSerializer.new(provider, root: false, scope: guardian)
        end
      }.to_json
    end

    seq = nil

    if guardian.anonymous?
      seq = MessageBus.last_id('/site_json')

      cached_json, cached_seq, cached_version = $redis.mget('site_json', 'site_json_seq', 'site_json_version')

      if cached_json && seq == cached_seq.to_i && Discourse.git_version == cached_version
        return cached_json
      end

    end

    site = Site.new(guardian)
    json = MultiJson.dump(SiteSerializer.new(site, root: false, scope: guardian))

    if guardian.anonymous?
      $redis.multi do
        $redis.setex 'site_json', 1800, json
        $redis.set 'site_json_seq', seq
        $redis.set 'site_json_version', Discourse.git_version
      end
    end

    json
  end

  SITE_JSON_CHANNEL = '/site_json'

  def self.clear_anon_cache!
    # publishing forces the sequence up
    # the cache is validated based on the sequence
    MessageBus.publish(SITE_JSON_CHANNEL, '')
  end

end
