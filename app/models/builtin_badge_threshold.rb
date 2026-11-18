# frozen_string_literal: true

class BuiltinBadgeThreshold
  DEFINITIONS = {
    Badge::NicePost => ["Nice Reply", :reply_likes],
    Badge::GoodPost => ["Good Reply", :reply_likes],
    Badge::GreatPost => ["Great Reply", :reply_likes],
    Badge::NiceTopic => ["Nice Topic", :topic_likes],
    Badge::GoodTopic => ["Good Topic", :topic_likes],
    Badge::GreatTopic => ["Great Topic", :topic_likes],
    Badge::NiceShare => ["Nice Share", :share_visitors],
    Badge::GoodShare => ["Good Share", :share_visitors],
    Badge::GreatShare => ["Great Share", :share_visitors],
    Badge::PopularLink => ["Popular Link", :link_clicks],
    Badge::HotLink => ["Hot Link", :link_clicks],
    Badge::FamousLink => ["Famous Link", :link_clicks],
    Badge::Appreciated => ["Appreciated", :liked_posts, 1],
    Badge::Respected => ["Respected", :liked_posts, 2],
    Badge::Admired => ["Admired", :liked_posts, 5],
    Badge::OutOfLove => ["Out of Love", :like_limit_days],
    Badge::HigherLove => ["Higher Love", :like_limit_days],
    Badge::CrazyInLove => ["Crazy in Love", :like_limit_days],
    Badge::Enthusiast => ["Enthusiast", :consecutive_visits],
    Badge::Aficionado => ["Aficionado", :consecutive_visits],
    Badge::Devotee => ["Devotee", :consecutive_visits],
  }.freeze

  def self.for(badge)
    return unless badge.system?
    definition = DEFINITIONS[badge.id]
    return unless definition

    setting = SiteSetting.builtin_badge_thresholds
    return if setting == "[]"

    name, rule, minimum_likes = definition
    threshold = JSON.parse(setting).find { |entry| entry["badge"] == name }
    new(rule, threshold["threshold"], minimum_likes) if threshold
  end

  def initialize(rule, count, minimum_likes)
    @rule = rule
    @count = count.to_i
    @minimum_likes = minimum_likes
  end

  def query
    case @rule
    when :reply_likes
      BadgeQueries.like_badge(@count, false)
    when :topic_likes
      BadgeQueries.like_badge(@count, true)
    when :share_visitors
      BadgeQueries.sharing_badge(@count)
    when :link_clicks
      BadgeQueries.linking_badge(@count)
    when :liked_posts
      BadgeQueries.liked_posts(@count - 1, @minimum_likes)
    when :like_limit_days
      BadgeQueries.like_rate_limit(@count)
    when :consecutive_visits
      BadgeQueries.consecutive_visits(@count)
    end
  end

  def description
    rule = @minimum_likes == 1 ? :single_like_posts : @rule
    I18n.t("badges.builtin_thresholds.#{rule}", count: @count, minimum_likes: @minimum_likes)
  end
end
