# frozen_string_literal: true

DiscourseAutomation::Triggerable::TOPIC = "topic"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::TOPIC) do
  field :restricted_topic, component: :text

  on_update do |automation, metadata, previous_metadata|
    ActiveRecord::Base.transaction do
      previous_topic_id = previous_metadata.dig("restricted_topic", "value")
      topic_id = metadata.dig("restricted_topic", "value")

      if previous_topic_id && previous_topic_id != topic_id
        previous_topic = Topic.find_by(id: previous_topic_id)

        if previous_topic
          TopicCustomField.where(
            topic_id: previous_topic_id,
            name: DiscourseAutomation::CUSTOM_FIELD,
            value: automation.id,
          ).delete_all
        end
      end

      if topic_id
        topic = Topic.find_by(id: topic_id)
        topic&.upsert_custom_fields(DiscourseAutomation::CUSTOM_FIELD => automation.id)
      end
    end
  end
end
