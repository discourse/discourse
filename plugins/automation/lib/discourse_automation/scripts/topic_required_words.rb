# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::TOPIC_REQUIRED_WORDS) do
  field :words, component: :text_list

  version 1

  triggerables %i[topic]
end
