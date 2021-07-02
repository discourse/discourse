# frozen_string_literal: true

DiscourseAutomation::Triggerable::TOPIC = 'topic'

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::TOPIC) do
  field :restricted_topic, component: :text

  on_update do |automation, metadata, previous_metadata|
    ActiveRecord::Base.transaction do
      previous_topic_id = previous_metadata.dig('restricted_topic', 'value')
      topic_id = metadata.dig('restricted_topic', 'value')

      if previous_topic_id && previous_topic_id != topic_id
        previous_topic = Topic.find_by(id: previous_topic_id)

        if previous_topic
          previous_topic.custom_fields.delete('discourse_automation_id')
          previous_topic.save!
        end
      end

      if topic_id
        topic = Topic.find_by(id: topic_id)
        topic&.upsert_custom_fields({ discourse_automation_id: automation.id })
      end
    end
  end
end
