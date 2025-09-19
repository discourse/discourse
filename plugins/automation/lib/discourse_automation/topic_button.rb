# frozen_string_literal: true

module DiscourseAutomation
  class TopicButton
    attr_reader :automation, :topic, :user

    def self.for_topic(topic, user)
      return [] if topic.blank? || user.blank?
      return [] unless SiteSetting.discourse_automation_enabled

      enabled_automations.map { |automation| new(automation, topic:, user:) }.select(&:available?)
    end

    def self.enabled_automations
      return DiscourseAutomation::Automation.none unless SiteSetting.discourse_automation_enabled

      DiscourseAutomation::Automation.where(
        script: DiscourseAutomation::Scripts::MANUAL_TOPIC_BUTTON,
        trigger: DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON,
        enabled: true,
      ).includes(:fields)
    end

    def initialize(automation, topic:, user:)
      @automation = automation
      @topic = topic
      @user = user
    end

    def available?
      applies_to_topic? && allowed?
    end

    def applies_to_topic?
      category_ids.blank? || category_ids.include?(topic.category_id)
    end

    def allowed?
      return false if configured_actions.blank?

      return false if button_label.blank?

      guardian = Guardian.new(user)

      return false unless guardian.can_trigger_automation?(automation, topic)

      if timer_action?
        permission_check =
          case timer_type
          when "open"
            :can_open_topic?
          else
            :can_close_topic?
          end

        return false unless guardian.public_send(permission_check, topic)
      end

      if configured_actions.include?(:tags)
        return false unless guardian.can_edit_tags?(topic)
      end

      true
    end

    def to_h
      {
        automation_id: automation.id,
        icon: button_icon,
        label: button_label,
        success_message:
          I18n.t("discourse_automation.topic_manual_button.success", name: automation.name),
        actions: configured_actions.map(&:to_s),
      }
    end

    def context
      {
        "kind" => DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON,
        "topic" => topic,
        "user" => user,
      }
    end

    def configured_actions
      @configured_actions ||=
        begin
          actions = []

          actions << :topic_timer if timer_action?

          tags = Array(automation.script_field("tags")["value"]).compact_blank
          actions << :tags if tags.present?

          actions.freeze
        end
    end

    def category_ids
      @category_ids ||= Array(automation.trigger_field("categories")["value"]).map(&:to_i)
    end

    private

    def button_label
      automation.script_field("button_label")["value"].to_s
    end

    def button_icon
      automation.script_field("button_icon")["value"].presence
    end

    def timer_type
      automation.script_field("timer_type")["value"].presence || "none"
    end

    def timer_action?
      timer_type != "none" &&
        Scripts::ManualTopicButton.hours_from_period(
          automation.script_field("topic_timer")["value"],
        ).present?
    end
  end
end
