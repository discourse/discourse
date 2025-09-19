# frozen_string_literal: true

module DiscourseAutomation
  module Scripts
    module ManualTopicButton
      FREQUENCY_CHOICES = [
        {
          id: "minute",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.topic_timer.choices.minute",
        },
        {
          id: "hour",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.topic_timer.choices.hour",
        },
        {
          id: "day",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.topic_timer.choices.day",
        },
        {
          id: "week",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.topic_timer.choices.week",
        },
      ].freeze

      HOURS_PER_FREQUENCY = {
        "minute" => 1.0 / 60,
        "hour" => 1,
        "day" => 24,
        "week" => 24 * 7,
      }.freeze

      TIMER_TYPE_CHOICES = [
        {
          id: "close",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.timer_type.choices.close",
        },
        {
          id: "open",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.timer_type.choices.open",
        },
        {
          id: "none",
          name:
            "discourse_automation.scriptables.manual_topic_button.fields.timer_type.choices.none",
        },
      ].freeze

      def self.hours_from_period(value)
        return if value.blank?

        interval = value["interval"].to_i
        frequency = value["frequency"].to_s

        return if interval <= 0

        multiplier = HOURS_PER_FREQUENCY[frequency]
        return if multiplier.blank?

        interval * multiplier
      end
    end
  end
end

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::MANUAL_TOPIC_BUTTON) do
  version 1

  field :button_label, component: :text, required: true
  field :button_icon, component: :icon
  field :timer_type,
        component: :choices,
        extra: {
          content: DiscourseAutomation::Scripts::ManualTopicButton::TIMER_TYPE_CHOICES,
        },
        default_value: "none"
  field :topic_timer,
        component: :period,
        extra: {
          content: DiscourseAutomation::Scripts::ManualTopicButton::FREQUENCY_CHOICES,
          hide_recurring_label: true,
        }
  field :tags, component: :tags

  triggerables %i[topic_manual_button]

  script do |context, fields, _automation|
    topic = context["topic"]
    user = context["user"]

    next if topic.blank? || user.blank?

    guardian = Guardian.new(user)

    timer_type = fields.dig("timer_type", "value").presence || "none"
    timer_config = fields.dig("topic_timer", "value")
    timer_hours = DiscourseAutomation::Scripts::ManualTopicButton.hours_from_period(timer_config)

    if timer_type != "none"
      raise Discourse::InvalidParameters if timer_hours.blank?

      timer_enum = TopicTimer.types[timer_type.to_sym]
      raise Discourse::InvalidParameters if timer_enum.blank?

      permission_check =
        case timer_type
        when "open"
          :can_open_topic?
        else
          :can_close_topic?
        end

      raise Discourse::InvalidAccess unless guardian.public_send(permission_check, topic)

      topic.set_or_create_timer(timer_enum, timer_hours, by_user: user)
    end

    tags = Array(fields.dig("tags", "value")).compact_blank

    if tags.present?
      raise Discourse::InvalidAccess unless guardian.can_edit_tags?(topic)

      DiscourseTagging.tag_topic_by_names(topic, guardian, tags, append: true)
    end
  end
end
