# frozen_string_literal: true

class About
  class CategoryMods
    include ActiveModel::Serialization
    attr_reader :category, :moderators

    def initialize(category, moderators)
      @category = category
      @moderators = moderators
    end

    def parent_category
      category.parent_category
    end
  end

  include ActiveModel::Serialization
  include StatsCacheable

  def self.stats_cache_key
    "about-stats"
  end

  def self.fetch_stats
    Stat.api_stats
  end

  def initialize(user = nil)
    @user = user
  end

  def version
    Discourse::VERSION::STRING
  end

  def https
    SiteSetting.force_https
  end

  def title
    SiteSetting.title
  end

  def locale
    SiteSetting.default_locale
  end

  def description
    SiteSetting.site_description
  end

  def extended_site_description
    SiteSetting.extended_site_description_cooked
  end

  def banner_image
    url = SiteSetting.about_banner_image&.url
    return if url.blank?
    GlobalPath.full_cdn_url(url)
  end

  def site_creation_date
    Discourse.site_creation_date
  end

  def moderators
    @moderators ||=
      apply_excluded_groups(
        User.where(moderator: true, admin: false).human_users.order(last_seen_at: :desc),
      )
  end

  def admins
    @admins ||=
      DiscoursePluginRegistry.apply_modifier(
        :about_admins,
        apply_excluded_groups(User.where(admin: true).human_users.order(last_seen_at: :desc)),
      )
  end

  def stats
    @stats ||= About.fetch_cached_stats
  end

  def category_moderators
    allowed_cats = Guardian.new(@user).allowed_category_ids
    return [] if allowed_cats.blank?

    cats_with_mods = Category.joins(:category_moderation_groups).distinct.pluck(:id)

    category_ids = cats_with_mods & allowed_cats
    return [] if category_ids.blank?

    per_cat_limit = category_mods_limit / category_ids.size
    per_cat_limit = 1 if per_cat_limit < 1

    results = DB.query(<<~SQL, category_ids:)
      WITH moderator_users AS (
        SELECT
          cmg.category_id AS category_id,
          u.id AS user_id,
          u.last_seen_at,
          ROW_NUMBER() OVER (PARTITION BY cmg.category_id, u.id ORDER BY u.last_seen_at DESC) as rn
        FROM category_moderation_groups cmg
        INNER JOIN group_users gu
          ON cmg.group_id = gu.group_id
        INNER JOIN users u
          ON gu.user_id = u.id
        WHERE cmg.category_id IN (:category_ids)
      )
      SELECT id AS category_id, user_ids
      FROM categories
      INNER JOIN (
        SELECT
          category_id,
          (ARRAY_AGG(user_id ORDER BY last_seen_at DESC))[:#{per_cat_limit}] AS user_ids
        FROM moderator_users
        WHERE rn = 1
        GROUP BY category_id
      ) X
      ON X.category_id = id
      ORDER BY position
    SQL

    cats = Category.where(id: results.map(&:category_id)).index_by(&:id)
    mods = User.where(id: results.map(&:user_ids).flatten.uniq).index_by(&:id)

    results.map { |row| CategoryMods.new(cats[row.category_id], mods.values_at(*row.user_ids)) }
  end

  def category_mods_limit
    @category_mods_limit || 100
  end

  def category_mods_limit=(number)
    @category_mods_limit = number
  end

  private

  def apply_excluded_groups(query)
    group_ids = SiteSetting.about_page_hidden_groups_map
    return query if group_ids.blank?

    query.joins(
      DB.sql_fragment(
        "LEFT JOIN group_users ON group_id IN (:group_ids) AND user_id = users.id",
        group_ids:,
      ),
    ).where("group_users.id": nil)
  end
end
