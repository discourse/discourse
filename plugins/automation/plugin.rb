# frozen_string_literal: true

# name: discourse-automation
# about: Lets you automate actions on your Discourse Forum
# version: 0.1
# authors: jjaffeux
# url: https://github.com/discourse/discourse-automation
# transpile_js: true

gem "iso8601", "0.13.0"
gem "rrule", "0.4.4"

enabled_site_setting :discourse_automation_enabled

register_asset "stylesheets/common/discourse-automation.scss"

module ::DiscourseAutomation
  PLUGIN_NAME = "discourse-automation"

  CUSTOM_FIELD = "discourse_automation_ids"
  TOPIC_LAST_CHECKED_BY = "discourse_automation_last_checked_by"
  TOPIC_LAST_CHECKED_AT = "discourse_automation_last_checked_at"
end

require_relative "lib/discourse_automation/engine"
require_relative "lib/discourse_automation/scriptable"
require_relative "lib/discourse_automation/triggerable"
require_relative "lib/plugin/instance"

after_initialize do
  %w[
    app/jobs/regular/discourse_automation_call_zapier_webhook
    app/jobs/scheduled/discourse_automation_tracker
    app/jobs/scheduled/stalled_topic_tracker
    app/jobs/scheduled/stalled_wiki_tracker
    app/queries/stalled_topic_finder
    app/services/discourse_automation/user_badge_granted_handler
    lib/discourse_automation/event_handlers
    lib/discourse_automation/post_extension
    lib/discourse_automation/scripts/add_user_to_group_through_custom_field
    lib/discourse_automation/scripts/append_last_checked_by
    lib/discourse_automation/scripts/append_last_edited_by
    lib/discourse_automation/scripts/auto_responder
    lib/discourse_automation/scripts/banner_topic
    lib/discourse_automation/scripts/close_topic
    lib/discourse_automation/scripts/flag_post_on_words
    lib/discourse_automation/scripts/gift_exchange
    lib/discourse_automation/scripts/group_category_notification_default
    lib/discourse_automation/scripts/pin_topic
    lib/discourse_automation/scripts/post
    lib/discourse_automation/scripts/send_pms
    lib/discourse_automation/scripts/suspend_user_by_email
    lib/discourse_automation/scripts/topic_required_words
    lib/discourse_automation/scripts/user_global_notice
    lib/discourse_automation/scripts/zapier_webhook
    lib/discourse_automation/triggers/after_post_cook
    lib/discourse_automation/triggers/api_call
    lib/discourse_automation/triggers/category_created_edited
    lib/discourse_automation/triggers/pm_created
    lib/discourse_automation/triggers/point_in_time
    lib/discourse_automation/triggers/post_created_edited
    lib/discourse_automation/triggers/recurring
    lib/discourse_automation/triggers/stalled_topic
    lib/discourse_automation/triggers/stalled_wiki
    lib/discourse_automation/triggers/topic
    lib/discourse_automation/triggers/user_added_to_group
    lib/discourse_automation/triggers/user_badge_granted
    lib/discourse_automation/triggers/user_promoted
    lib/discourse_automation/triggers/user_removed_from_group
  ].each { |path| require_relative path }

  reloadable_patch { Post.prepend DiscourseAutomation::PostExtension }

  add_admin_route "discourse_automation.title", "discourse-automation"

  add_api_key_scope(
    :automations_trigger,
    {
      post: {
        actions: %w[discourse_automation/automations#trigger],
        params: %i[context],
        formats: :json,
      },
    },
  )

  add_to_serializer(:current_user, :global_notices) do
    notices = DiscourseAutomation::UserGlobalNotice.where(user_id: object.id)
    ActiveModel::ArraySerializer.new(
      notices,
      each_serializer: DiscourseAutomation::UserGlobalNoticeSerializer,
    ).as_json
  end

  on(:user_added_to_group) do |user, group|
    name = DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP

    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each do |automation|
        joined_group = automation.trigger_field("joined_group")
        if joined_group["value"] == group.id
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
            "usernames" => [user.username],
            "group" => group,
            "placeholders" => {
              "group_name" => group.name,
            },
          )
        end
      end
  end

  on(:user_removed_from_group) do |user, group|
    name = DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP

    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each do |automation|
        left_group = automation.trigger_field("left_group")
        if left_group["value"] == group.id
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP,
            "usernames" => [user.username],
            "group" => group,
            "placeholders" => {
              "group_name" => group.name,
            },
          )
        end
      end
  end

  on(:user_badge_granted) do |badge_id, user_id|
    name = DiscourseAutomation::Triggerable::USER_BADGE_GRANTED
    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each do |automation|
        DiscourseAutomation::UserBadgeGrantedHandler.handle(automation, badge_id, user_id)
      end
  end

  on(:user_promoted) do |payload|
    user_id, new_trust_level, old_trust_level =
      payload.values_at(:user_id, :new_trust_level, :old_trust_level)

    DiscourseAutomation::EventHandlers.handle_user_promoted(
      user_id,
      new_trust_level,
      old_trust_level,
    )
  end

  on(:topic_created) do |topic|
    DiscourseAutomation::EventHandlers.handle_pm_created(topic) if topic.private_message?
  end

  on(:post_created) do |post|
    DiscourseAutomation::EventHandlers.handle_post_created_edited(post, :create)
  end

  on(:post_edited) do |post|
    DiscourseAutomation::EventHandlers.handle_post_created_edited(post, :edit)
  end

  on(:category_created) do |category|
    DiscourseAutomation::EventHandlers.handle_category_created_edited(category, :create)
  end

  on(:category_edited) do |category|
    DiscourseAutomation::EventHandlers.handle_category_created_edited(category, :edit)
  end

  Plugin::Filter.register(:after_post_cook) do |post, cooked|
    DiscourseAutomation::EventHandlers.handle_after_post_cook(post, cooked)
  end

  on(:post_created) do |post|
    next if post.user_id != post.topic.user_id

    DiscourseAutomation::Automation
      .where(trigger: DiscourseAutomation::Triggerable::STALLED_TOPIC)
      .where(enabled: true)
      .find_each do |automation|
        fields = automation.serialized_fields

        categories = fields.dig("categories", "value")
        next if categories && !categories.include?(post.topic.category_id)

        tags = fields.dig("tags", "value")
        next if tags && (tags & post.topic.tags.map(&:name)).empty?

        DiscourseAutomation::UserGlobalNotice
          .where(identifier: automation.id)
          .where(user_id: post.user_id)
          .destroy_all
      end
  end

  register_topic_custom_field_type(DiscourseAutomation::CUSTOM_FIELD, [:integer])
  register_topic_custom_field_type(
    DiscourseAutomation::Scriptable::AUTO_RESPONDER_TRIGGERED_IDS,
    [:integer],
  )
  register_user_custom_field_type(DiscourseAutomation::CUSTOM_FIELD, [:integer])
  register_post_custom_field_type(DiscourseAutomation::CUSTOM_FIELD, [:integer])
  register_post_custom_field_type("stalled_wiki_triggered_at", :string)
end
