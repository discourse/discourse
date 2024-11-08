# frozen_string_literal: true

# name: automation
# about: Allows admins to automate actions through scripts and triggers. Customisation is made through an automatically generated UI.
# meta_topic_id: 195773
# version: 0.1
# authors: jjaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/automation

enabled_site_setting :discourse_automation_enabled

register_asset "stylesheets/common/discourse-automation.scss"

module ::DiscourseAutomation
  PLUGIN_NAME = "automation"

  AUTOMATION_IDS_CUSTOM_FIELD = "discourse_automation_ids_json"
  TOPIC_LAST_CHECKED_BY = "discourse_automation_last_checked_by"
  TOPIC_LAST_CHECKED_AT = "discourse_automation_last_checked_at"

  USER_PROMOTED_TRUST_LEVEL_CHOICES = [
    { id: "TLALL", name: "discourse_automation.triggerables.user_promoted.trust_levels.ALL" },
    { id: "TL01", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL01" },
    { id: "TL12", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL12" },
    { id: "TL23", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL23" },
    { id: "TL34", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL34" },
  ].freeze

  AUTO_RESPONDER_TRIGGERED_IDS = "auto_responder_triggered_ids_json"
  USER_GROUP_MEMBERSHIP_THROUGH_BADGE_BULK_MODIFY_START_COUNT = 1000

  def self.set_active_automation(id)
    Thread.current[:active_automation_id] = id
  end

  def self.get_active_automation
    Thread.current[:active_automation_id]
  end
end

require_relative "lib/discourse_automation/engine"

after_initialize do
  %w[
    lib/discourse_automation/scripts
    lib/discourse_automation/scripts/add_user_to_group_through_custom_field
    lib/discourse_automation/scripts/append_last_checked_by
    lib/discourse_automation/scripts/append_last_edited_by
    lib/discourse_automation/scripts/auto_responder
    lib/discourse_automation/scripts/auto_tag_topic
    lib/discourse_automation/scripts/banner_topic
    lib/discourse_automation/scripts/close_topic
    lib/discourse_automation/scripts/flag_post_on_words
    lib/discourse_automation/scripts/gift_exchange
    lib/discourse_automation/scripts/group_category_notification_default
    lib/discourse_automation/scripts/pin_topic
    lib/discourse_automation/scripts/post
    lib/discourse_automation/scripts/topic
    lib/discourse_automation/scripts/send_pms
    lib/discourse_automation/scripts/suspend_user_by_email
    lib/discourse_automation/scripts/topic_required_words
    lib/discourse_automation/scripts/user_global_notice
    lib/discourse_automation/scripts/user_group_membership_through_badge
    lib/discourse_automation/scripts/zapier_webhook
    lib/discourse_automation/triggers
    lib/discourse_automation/triggers/after_post_cook
    lib/discourse_automation/triggers/api_call
    lib/discourse_automation/triggers/category_created_edited
    lib/discourse_automation/triggers/pm_created
    lib/discourse_automation/triggers/point_in_time
    lib/discourse_automation/triggers/post_created_edited
    lib/discourse_automation/triggers/recurring
    lib/discourse_automation/triggers/stalled_topic
    lib/discourse_automation/triggers/stalled_wiki
    lib/discourse_automation/triggers/topic_tags_changed
    lib/discourse_automation/triggers/topic
    lib/discourse_automation/triggers/user_added_to_group
    lib/discourse_automation/triggers/user_badge_granted
    lib/discourse_automation/triggers/user_promoted
    lib/discourse_automation/triggers/user_removed_from_group
    lib/discourse_automation/triggers/user_first_logged_in
    lib/discourse_automation/triggers/user_updated
  ].each { |path| require_relative path }

  reloadable_patch do
    Post.prepend DiscourseAutomation::PostExtension
    Plugin::Instance.prepend DiscourseAutomation::PluginInstanceExtension
  end

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

  on(:user_first_logged_in) do |user|
    name = DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN

    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each { |automation| automation.trigger!("kind" => name, "user" => user) }
  end

  on(:user_added_to_group) do |user, group|
    name = DiscourseAutomation::Triggers::USER_ADDED_TO_GROUP

    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each do |automation|
        joined_group = automation.trigger_field("joined_group")
        if joined_group["value"] == group.id
          automation.trigger!(
            "kind" => name,
            "usernames" => [user.username],
            "user" => user,
            "group" => group,
            "placeholders" => {
              "group_name" => group.name,
            },
          )
        end
      end
  end

  on(:user_removed_from_group) do |user, group|
    name = DiscourseAutomation::Triggers::USER_REMOVED_FROM_GROUP

    DiscourseAutomation::Automation
      .where(trigger: name, enabled: true)
      .find_each do |automation|
        left_group = automation.trigger_field("left_group")
        if left_group["value"] == group.id
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggers::USER_REMOVED_FROM_GROUP,
            "usernames" => [user.username],
            "user" => user,
            "group" => group,
            "placeholders" => {
              "group_name" => group.name,
            },
          )
        end
      end
  end

  on(:user_badge_granted) do |badge_id, user_id|
    name = DiscourseAutomation::Triggers::USER_BADGE_GRANTED
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

  on(:topic_tags_changed) do |topic, payload|
    old_tag_names, new_tag_names, user = payload.values_at(:old_tag_names, :new_tag_names, :user)

    DiscourseAutomation::EventHandlers.handle_topic_tags_changed(
      topic,
      old_tag_names,
      new_tag_names,
      user,
    )
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

  on(:post_created) { |post| DiscourseAutomation::EventHandlers.handle_stalled_topic(post) }

  register_topic_custom_field_type(DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD, :json)
  register_topic_custom_field_type(DiscourseAutomation::AUTO_RESPONDER_TRIGGERED_IDS, :json)

  on(:user_updated) { |user| DiscourseAutomation::EventHandlers.handle_user_updated(user) }
  on(:user_created) do |user|
    DiscourseAutomation::EventHandlers.handle_user_updated(user, new_user: true)
  end

  register_user_custom_field_type(DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD, :json)
  register_post_custom_field_type(DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD, :json)
  register_post_custom_field_type("stalled_wiki_triggered_at", :string)
end
