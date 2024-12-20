# frozen_string_literal: true

module DiscourseAutomation
  module Triggers
    module TopicTagsChanged
      module TriggerOn
        TAGS_ADDED_OR_REMOVED = "tags_added_or_removed"
        TAGS_ADDED = "tags_added"
        TAGS_REMOVED = "tags_removed"

        MODES = [
          {
            id: TAGS_ADDED_OR_REMOVED,
            name:
              "discourse_automation.triggerables.topic_tags_changed.trigger_on_modes.tags_added_or_removed",
          },
          {
            id: TAGS_ADDED,
            name:
              "discourse_automation.triggerables.topic_tags_changed.trigger_on_modes.tags_added",
          },
          {
            id: TAGS_REMOVED,
            name:
              "discourse_automation.triggerables.topic_tags_changed.trigger_on_modes.tags_removed",
          },
        ]
      end
    end
  end
end

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED) do
  field :watching_categories, component: :categories
  field :watching_tags, component: :tags
  field :trigger_on,
        component: :choices,
        extra: {
          content: DiscourseAutomation::Triggers::TopicTagsChanged::TriggerOn::MODES,
          default_value:
            DiscourseAutomation::Triggers::TopicTagsChanged::TriggerOn::TAGS_ADDED_OR_REMOVED,
        },
        required: true

  field :trigger_with_pms, component: :boolean

  placeholder :topic_url
  placeholder :topic_title
end
