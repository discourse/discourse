# frozen_string_literal: true

class About
  def self.displayed_plugin_stat_groups
    DiscoursePluginRegistry.stats.select { |stat| stat.show_in_ui }.map { |stat| stat.name }
  end

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

  def moderators
    @moderators ||= User.where(moderator: true, admin: false).human_users.order("last_seen_at DESC")
  end

  def admins
    @admins ||= User.where(admin: true).human_users.order("last_seen_at DESC")
  end

  def stats
    @stats ||= About.fetch_stats
  end

  def category_moderators
    allowed_cats = Guardian.new(@user).allowed_category_ids
    return [] if allowed_cats.blank?

    cats_with_mods = Category.where.not(reviewable_by_group_id: nil).pluck(:id)

    category_ids = cats_with_mods & allowed_cats
    return [] if category_ids.blank?

    per_cat_limit = category_mods_limit / category_ids.size
    per_cat_limit = 1 if per_cat_limit < 1

    results = DB.query(<<~SQL, category_ids: category_ids)
        SELECT c.id category_id
             , (ARRAY_AGG(u.id ORDER BY u.last_seen_at DESC))[:#{per_cat_limit}] user_ids
          FROM categories c
          JOIN group_users gu ON gu.group_id = c.reviewable_by_group_id
          JOIN users u ON u.id = gu.user_id
         WHERE c.id IN (:category_ids)
      GROUP BY c.id
      ORDER BY c.position
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
end
