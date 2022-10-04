# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'TopicRequiredWords' do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::TOPIC_REQUIRED_WORDS,
      trigger: DiscourseAutomation::Triggerable::TOPIC,
    )
  end

  context 'when updating trigger' do
    it 'updates the custom field' do
      automation.upsert_field!('restricted_topic', 'text', { value: topic.id }, target: 'trigger')
      expect(topic.custom_fields['discourse_automation_ids']).to eq([automation.id])

      new_topic = create_topic
      automation.upsert_field!('restricted_topic', 'text', { value: new_topic.id }, target: 'trigger')
      expect(new_topic.custom_fields['discourse_automation_ids']).to eq([automation.id])
    end
  end
end
