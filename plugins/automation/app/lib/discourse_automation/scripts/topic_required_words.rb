# frozen_string_literal: true

DiscourseAutomation::Scriptable::TOPIC_REQUIRED_WORDS = "topic_required_words"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::TOPIC_REQUIRED_WORDS) do
  field :words, component: :text_list

  version 1

  triggerables %i[topic]
end
