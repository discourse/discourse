# frozen_string_literal: true

class About
  def self.displayed_plugin_stat_groups
    DiscoursePluginRegistry
      .about_stat_groups
      .select { |stat_group| stat_group[:show_in_ui] }
      .map { |stat_group| stat_group[:name] }
  end

  class CategoryMods
    include ActiveModel::Serialization
    attr_reader :category_id, :moderators

    def initialize(category_id, moderators)
      @category_id = category_id
      @moderators = moderators
    end
  end

  include ActiveModel::Serialization
  include StatsCacheable

  attr_accessor :moderators, :admins

  def self.stats_cache_key
    "about-stats"
  end

  def self.fetch_stats
    About.new.stats
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
    @stats ||= {
      topic_count: Topic.listable_topics.count,
      topics_last_day: Topic.listable_topics.where("created_at > ?", 1.days.ago).count,
      topics_7_days: Topic.listable_topics.where("created_at > ?", 7.days.ago).count,
      topics_30_days: Topic.listable_topics.where("created_at > ?", 30.days.ago).count,
      post_count: Post.count,
      posts_last_day: Post.where("created_at > ?", 1.days.ago).count,
      posts_7_days: Post.where("created_at > ?", 7.days.ago).count,
      posts_30_days: Post.where("created_at > ?", 30.days.ago).count,
      user_count: User.real.count,
      users_last_day: User.real.where("created_at > ?", 1.days.ago).count,
      users_7_days: User.real.where("created_at > ?", 7.days.ago).count,
      users_30_days: User.real.where("created_at > ?", 30.days.ago).count,
      active_users_last_day: User.where("last_seen_at > ?", 1.days.ago).count,
      active_users_7_days: User.where("last_seen_at > ?", 7.days.ago).count,
      active_users_30_days: User.where("last_seen_at > ?", 30.days.ago).count,
      like_count: UserAction.where(action_type: UserAction::LIKE).count,
      likes_last_day:
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 1.days.ago).count,
      likes_7_days:
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 7.days.ago).count,
      likes_30_days:
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 30.days.ago).count,
    }.merge(plugin_stats)
  end

  def plugin_stats
    final_plugin_stats = {}
    DiscoursePluginRegistry.about_stat_groups.each do |stat_group|
      begin
        stats = stat_group[:block].call
      rescue StandardError => err
        Discourse.warn_exception(
          err,
          message: "Unexpected error when collecting #{stat_group[:name]} About stats.",
        )
        next
      end

      if !stats.key?(:last_day) || !stats.key?("7_days") || !stats.key?("30_days") ||
           !stats.key?(:count)
        Rails.logger.warn(
          "Plugin stat group #{stat_group[:name]} for About stats does not have all required keys, skipping.",
        )
      else
        final_plugin_stats.merge!(
          stats.transform_keys { |key| "#{stat_group[:name]}_#{key}".to_sym },
        )
      end
    end
    final_plugin_stats
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

    mods = User.where(id: results.map(&:user_ids).flatten.uniq).index_by(&:id)

    results.map { |row| CategoryMods.new(row.category_id, mods.values_at(*row.user_ids)) }
  end

  def category_mods_limit
    @category_mods_limit || 100
  end

  def category_mods_limit=(number)
    @category_mods_limit = number
  end
end
