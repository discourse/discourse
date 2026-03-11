# frozen_string_literal: true

# name: discourse-boosts
# about: Allows users to add freeform micro-reactions (boosts) to posts.
# version: 0.1
# authors: jjaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-boosts

enabled_site_setting :discourse_boosts_enabled

register_asset "stylesheets/common/discourse-boosts.scss"

register_svg_icon "rocket"
register_svg_icon "trash-can"

module ::DiscourseBoosts
  PLUGIN_NAME = "discourse-boosts"
end

require_relative "lib/discourse_boosts/engine"

after_initialize do
  reloadable_patch do |plugin|
    Post.prepend DiscourseBoosts::PostExtension
    Notification.singleton_class.prepend DiscourseBoosts::NotificationExtension
  end

  Discourse::Application.routes.append { mount DiscourseBoosts::Engine, at: "/" }

  TopicView.on_preload do |topic_view|
    if SiteSetting.discourse_boosts_enabled
      topic_view.instance_variable_set(:@posts, topic_view.posts.includes(boosts: :user))
    end
  end

  add_to_serializer(
    :post,
    :boosts,
    include_condition: -> { SiteSetting.discourse_boosts_enabled },
  ) do
    object
      .boosts
      .sort_by(&:created_at)
      .map do |boost|
        DiscourseBoosts::BoostSerializer.new(boost, scope: scope, root: false).as_json
      end
  end

  add_to_serializer(
    :post,
    :can_boost,
    include_condition: -> { SiteSetting.discourse_boosts_enabled },
  ) { scope.user.present? && object.user_id != scope.user&.id }

  UserUpdater::OPTION_ATTR.push(:boost_notifications_level)

  add_to_serializer(:user_option, :boost_notifications_level) { object.boost_notifications_level }

  register_notification_consolidation_plan(
    DiscourseBoosts::NotificationConsolidation.boosted_by_multiple_users_plan,
  )
  register_notification_consolidation_plan(
    DiscourseBoosts::NotificationConsolidation.consolidated_boosts_plan,
  )
end
