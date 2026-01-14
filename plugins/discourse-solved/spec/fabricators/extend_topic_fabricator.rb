# frozen_string_literal: true
Fabricator(:custom_topic, from: :topic) do
  transient :custom_topic_name
  transient :value
  after_create do |top, transients|
    custom_topic =
      TopicCustomField.new(
        topic_id: top.id,
        name: transients[:custom_topic_name],
        value: transients[:value],
      )
    custom_topic.save
  end
end
