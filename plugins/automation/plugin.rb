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

require_relative "app/lib/discourse_automation/triggerable"
require_relative "app/lib/discourse_automation/scriptable"
require_relative "app/core_ext/plugin_instance"

after_initialize do
  module ::DiscourseAutomation
    PLUGIN_NAME = "discourse-automation"

    CUSTOM_FIELD = "discourse_automation_ids"
    TOPIC_LAST_CHECKED_BY = "discourse_automation_last_checked_by"
    TOPIC_LAST_CHECKED_AT = "discourse_automation_last_checked_at"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseAutomation
    end
  end

  %w[
    app/controllers/admin/discourse_automation/admin_discourse_automation_automations_controller
    app/controllers/admin/discourse_automation/admin_discourse_automation_controller
    app/controllers/admin/discourse_automation/admin_discourse_automation_scriptables_controller
    app/controllers/admin/discourse_automation/admin_discourse_automation_triggerables_controller
    app/controllers/discourse_automation/append_last_checked_by_controller
    app/controllers/discourse_automation/automations_controller
    app/controllers/discourse_automation/user_global_notices_controller
    app/jobs/regular/call_zapier_webhook
    app/jobs/scheduled/discourse_automation_tracker
    app/jobs/scheduled/stalled_topic_tracker
    app/jobs/scheduled/stalled_wiki_tracker
    app/lib/discourse_automation/event_handlers
    app/lib/discourse_automation/post_extension
    app/lib/discourse_automation/scripts/add_user_to_group_through_custom_field
    app/lib/discourse_automation/scripts/append_last_checked_by
    app/lib/discourse_automation/scripts/append_last_edited_by
    app/lib/discourse_automation/scripts/auto_responder
    app/lib/discourse_automation/scripts/banner_topic
    app/lib/discourse_automation/scripts/close_topic
    app/lib/discourse_automation/scripts/flag_post_on_words
    app/lib/discourse_automation/scripts/gift_exchange
    app/lib/discourse_automation/scripts/pin_topic
    app/lib/discourse_automation/scripts/post
    app/lib/discourse_automation/scripts/send_pms
    app/lib/discourse_automation/scripts/suspend_user_by_email
    app/lib/discourse_automation/scripts/topic_required_words
    app/lib/discourse_automation/scripts/user_global_notice
    app/lib/discourse_automation/scripts/zapier_webhook
    app/lib/discourse_automation/triggers/after_post_cook
    app/lib/discourse_automation/triggers/api_call
    app/lib/discourse_automation/triggers/pm_created
    app/lib/discourse_automation/triggers/point_in_time
    app/lib/discourse_automation/triggers/post_created_edited
    app/lib/discourse_automation/triggers/recurring
    app/lib/discourse_automation/triggers/stalled_topic
    app/lib/discourse_automation/triggers/stalled_wiki
    app/lib/discourse_automation/triggers/topic
    app/lib/discourse_automation/triggers/user_added_to_group
    app/lib/discourse_automation/triggers/user_badge_granted
    app/lib/discourse_automation/triggers/user_promoted
    app/lib/discourse_automation/triggers/user_removed_from_group
    app/models/discourse_automation/automation
    app/models/discourse_automation/field
    app/models/discourse_automation/pending_automation
    app/models/discourse_automation/pending_pm
    app/models/discourse_automation/user_global_notice
    app/queries/stalled_topic_finder
    app/serializers/discourse_automation/automation_field_serializer
    app/serializers/discourse_automation/automation_serializer
    app/serializers/discourse_automation/template_serializer
    app/serializers/discourse_automation/trigger_serializer
    app/serializers/discourse_automation/user_global_notice_serializer
    app/services/discourse_automation/user_badge_granted_handler
  ].each { |path| require_relative path }

  DiscourseAutomation::Engine.routes.draw do
    scope format: :json, constraints: AdminConstraint.new do
      post "/automations/:id/trigger" => "automations#trigger"
    end

    scope format: :json do
      delete "/user-global-notices/:id" => "user_global_notices#destroy"
      put "/append-last-checked-by/:post_id" => "append_last_checked_by#post_checked"
    end

    scope "/admin/plugins/discourse-automation",
          as: "admin_discourse_automation",
          constraints: AdminConstraint.new do
      scope format: false do
        get "/" => "admin_discourse_automation#index"
        get "/new" => "admin_discourse_automation#new"
        get "/:id" => "admin_discourse_automation#edit"
      end

      scope format: :json do
        get "/scriptables" => "admin_discourse_automation_scriptables#index"
        get "/triggerables" => "admin_discourse_automation_triggerables#index"
        get "/automations" => "admin_discourse_automation_automations#index"
        get "/automations/:id" => "admin_discourse_automation_automations#show"
        delete "/automations/:id" => "admin_discourse_automation_automations#destroy"
        put "/automations/:id" => "admin_discourse_automation_automations#update"
        post "/automations" => "admin_discourse_automation_automations#create"
      end
    end
  end

  Discourse::Application.routes.append { mount ::DiscourseAutomation::Engine, at: "/" }

  reloadable_patch { Post.class_eval { prepend DiscourseAutomation::PostExtension } }

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

Rake::Task.define_task run_automation: :environment do
  script_methods = DiscourseAutomation::Scriptable.all

  scripts = []

  DiscourseAutomation::Automation.find_each do |automation|
    script_methods.each do |name|
      type = name.to_s.gsub("script_", "")

      next if type != automation.script

      scriptable = automation.scriptable
      scriptable.public_send(name)
      scripts << scriptable.script.call
    end
  end
end
