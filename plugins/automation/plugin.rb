# frozen_string_literal: true

# name: automation
# about: Allows admins to automate actions through scripts and triggers. Customisation is made through an automatically generated UI.
# meta_topic_id: 195773
# version: 0.1
# authors: jjaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/automation

enabled_site_setting :discourse_automation_enabled

register_asset "stylesheets/common/discourse-automation.scss"
register_svg_icon "wand-magic-sparkles"

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
  ]

  AUTO_RESPONDER_TRIGGERED_IDS = "auto_responder_triggered_ids_json"
  USER_GROUP_MEMBERSHIP_THROUGH_BADGE_BULK_MODIFY_START_COUNT = 1000
  REMOVE_UPLOAD_MARKUP_FROM_DELETED_POSTS_BATCH_SIZE = 1000

  RECURSION_DEPTH_KEY = :discourse_automation_recursion_depth
  SUPPRESSED_TRIGGERS_KEY = :discourse_automation_suppressed_triggers

  def self.set_active_automation(_id)
    deprecated_active_automation_api
  end

  def self.get_active_automation
    deprecated_active_automation_api
  end

  def self.suppress_triggers
    raise StandardError, "Expecting a block" if !block_given?

    Thread.current[SUPPRESSED_TRIGGERS_KEY] = suppressed_triggers_count + 1
    begin
      yield
    ensure
      decrement_suppressed_triggers_count
    end
  end

  def self.triggers_suppressed?
    suppressed_triggers_count.positive?
  end

  def self.recursion_depth
    Thread.current[RECURSION_DEPTH_KEY] || 0
  end

  def self.max_recursion_depth
    SiteSetting.discourse_automation_max_recursion_depth
  end

  def self.increment_recursion_depth
    Thread.current[RECURSION_DEPTH_KEY] = recursion_depth + 1
  end

  def self.decrement_recursion_depth
    new_depth = recursion_depth - 1
    Thread.current[RECURSION_DEPTH_KEY] = new_depth.positive? ? new_depth : nil
  end

  def self.suppressed_triggers_count
    Thread.current[SUPPRESSED_TRIGGERS_KEY] || 0
  end

  def self.decrement_suppressed_triggers_count
    new_count = suppressed_triggers_count - 1
    Thread.current[SUPPRESSED_TRIGGERS_KEY] = new_count.positive? ? new_count : nil
  end

  def self.deprecated_active_automation_api
    Discourse.deprecate(
      "DiscourseAutomation.set_active_automation/get_active_automation are deprecated. " \
        "Use DiscourseAutomation.suppress_triggers instead.",
      since: "2026.6.0-latest",
      drop_from: "2026.8.0-latest",
      raise_error: true,
    )
  end
  private_class_method :suppressed_triggers_count,
                       :decrement_suppressed_triggers_count,
                       :deprecated_active_automation_api
end

require_relative "lib/discourse_automation/engine"

after_initialize do
  Dir
    .glob("./lib/discourse_automation/scripts/*.rb", base: __dir__)
    .each { |file| require_relative file }
  Dir
    .glob("./lib/discourse_automation/triggers/*.rb", base: __dir__)
    .each { |file| require_relative file }

  reloadable_patch do
    Post.prepend DiscourseAutomation::PostExtension
    Plugin::Instance.prepend DiscourseAutomation::PluginInstanceExtension
  end

  add_admin_route "discourse_automation.title", "automation", use_new_show_route: true

  add_api_key_scope(
    :automation,
    {
      trigger_automation: {
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

  on(:topic_closed) do |topic, status|
    ::DiscourseAutomation::EventHandlers.handle_topic_closed(topic, status)
  end

  on(:post_created) do |post|
    DiscourseAutomation::EventHandlers.handle_post_created_edited(post, :create)
  end

  on(:post_edited) do |post|
    DiscourseAutomation::EventHandlers.handle_post_created_edited(post, :edit)
  end

  on(:flag_created) do |post_action|
    DiscourseAutomation::EventHandlers.handle_post_flag_created(post_action) if post_action.post
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
