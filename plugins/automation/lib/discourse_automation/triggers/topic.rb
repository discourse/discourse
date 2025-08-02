# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::TOPIC) do
  field :restricted_topic, component: :text

  on_update do |automation, metadata, previous_metadata|
    ActiveRecord::Base.transaction do
      previous_topic_id = previous_metadata.dig("restricted_topic", "value")
      topic_id = metadata.dig("restricted_topic", "value")

      if previous_topic_id && previous_topic_id != topic_id
        previous_topic = Topic.find_by(id: previous_topic_id)

        if previous_topic
          automation.remove_id_from_custom_field(
            previous_topic,
            DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
          )
        end
      end

      if topic_id
        topic = Topic.find_by(id: topic_id)

        next if !topic

        automation.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      end
    end
  end
end
