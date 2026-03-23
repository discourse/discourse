# frozen_string_literal: true

# name: discourse-workflows
# about: Workflow automation system for Discourse
# meta_topic_id: TODO
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-workflows

enabled_site_setting :discourse_workflows_enabled

module ::DiscourseWorkflows
  PLUGIN_NAME = "discourse-workflows"
end

require_relative "lib/discourse_workflows/engine"

register_asset "stylesheets/common/index.scss"
register_svg_icon "bolt"
register_svg_icon "arrows-split-up-and-left"
register_svg_icon "list"
register_svg_icon "arrow-rotate-right"
register_svg_icon "arrows-turn-to-dots"
register_svg_icon "globe"
register_svg_icon "table"
register_svg_icon "expand"
register_svg_icon "magnifying-glass-minus"
register_svg_icon "magnifying-glass-plus"
register_svg_icon "user-check"
register_svg_icon "calendar-days"
register_svg_icon "rectangle-list"
register_svg_icon "shuffle"
register_svg_icon "trash-can"
register_svg_icon "broom"
register_svg_icon "arrow-pointer"

add_admin_route "discourse_workflows.admin.title", "discourse-workflows", use_new_show_route: true

after_initialize do
  reloadable_patch do
    %w[
      TopicClosed
      PostCreated
      TopicCreated
      TopicCategoryChanged
      StaleTopic
      Webhook
      Manual
      Schedule
      Form
    ].each do |name|
      DiscourseWorkflows::Registry.register_trigger(
        DiscourseWorkflows::Triggers.const_get(name)::V1,
      )
    end

    %w[
      AppendTags
      Code
      FetchTopic
      CreatePost
      CreateTopic
      SetFields
      SplitOut
      HttpRequest
      DataTable
      WaitForApproval
      AwardBadge
      Form
    ].each do |name|
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions.const_get(name)::V1)
    end

    %w[IfCondition Filter].each do |name|
      DiscourseWorkflows::Registry.register_condition(
        DiscourseWorkflows::Conditions.const_get(name)::V1,
      )
    end

    DiscourseWorkflows::Registry.register_core(DiscourseWorkflows::Core::LoopOverItems::V1)
  end

  DiscourseWorkflows::Registry.triggers.each do |trigger_class|
    next if trigger_class.event_name.nil?
    on(trigger_class.event_name) do |*args|
      DiscourseWorkflows::EventListener.handle(trigger_class, *args)
    end
  end

  on(:chat_message_interaction) do |interaction|
    next unless SiteSetting.discourse_workflows_enabled

    action_id = interaction.action&.dig("action_id")
    next unless action_id&.start_with?("dwf:")

    parts = action_id.split(":")
    next unless parts.length == 5

    _, execution_id, step_id, decision, signature = parts

    payload = "#{execution_id}:#{step_id}"
    next unless DiscourseWorkflows::HmacSigner.verify(payload, signature)

    Jobs.enqueue(
      Jobs::DiscourseWorkflows::ResumeExecution,
      execution_id: execution_id.to_i,
      approved: decision == "approve",
    )
  end
end
