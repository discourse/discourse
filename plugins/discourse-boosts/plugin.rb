# frozen_string_literal: true

# name: discourse-boosts
# about: Allows users to add freeform micro-reactions (boosts) to posts.
# version: 0.1
# authors: discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-boosts

enabled_site_setting :discourse_boosts_enabled

register_asset "stylesheets/common/discourse-boosts.scss"

register_svg_icon "rocket"
register_svg_icon "trash-can"
register_svg_icon "flag"

module ::DiscourseBoosts
  PLUGIN_NAME = "discourse-boosts"
end

require_relative "lib/discourse_boosts/engine"

after_initialize do
  reloadable_patch do |plugin|
    Post.prepend DiscourseBoosts::PostExtension
    UserOption.prepend DiscourseBoosts::UserOptionExtension
    Reviewable.prepend DiscourseBoosts::ReviewableExtension
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
    include_condition: -> do
      SiteSetting.discourse_boosts_enabled && object.association(:boosts).loaded?
    end,
  ) do
    boosts = object.boosts
    boost_ids = boosts.map(&:id)

    reviewables_by_target =
      if scope.user && boost_ids.present?
        Reviewable
          .includes(:reviewable_scores)
          .where(target_type: "DiscourseBoosts::Boost", target_id: boost_ids)
          .index_by(&:target_id)
      else
        {}
      end

    available_flags =
      Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:name_key)

    boosts.map do |boost|
      DiscourseBoosts::BoostSerializer.new(
        boost,
        scope: scope,
        root: false,
        reviewables_by_target: reviewables_by_target,
        available_flags: available_flags,
      ).as_json
    end
  end

  add_to_serializer(
    :post,
    :can_boost,
    include_condition: -> do
      SiteSetting.discourse_boosts_enabled && object.association(:boosts).loaded?
    end,
  ) do
    scope.user.present? && !scope.user.silenced? && object.user_id != scope.user&.id &&
      object.boosts.none? { |b| b.user_id == scope.user.id } &&
      object.boosts.size < SiteSetting.discourse_boosts_max_per_post
  end

  UserUpdater::OPTION_ATTR.push(:boost_notifications_level)

  add_to_serializer(:user_option, :boost_notifications_level) { object.boost_notifications_level }

  register_reviewable_type DiscourseBoosts::ReviewableBoost
  DiscoursePluginRegistry.register_flag_applies_to_type("DiscourseBoosts::Boost", self)

  register_notification_consolidation_plan(
    DiscourseBoosts::NotificationConsolidation.boosted_by_multiple_users_plan,
  )
  register_notification_consolidation_plan(
    DiscourseBoosts::NotificationConsolidation.consolidated_boosts_plan,
  )
end
