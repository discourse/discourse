# frozen_string_literal: true

DiscourseAutomation::Scriptable.add('topic_required_words') do
  field :words, component: :text_list

  version 1

  triggerables %i[topic]
end
