# frozen_string_literal: true

require 'rails_helper'

describe 'TopicRequiredWords' do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  let!(:automation) do
    DiscourseAutomation::Automation.create!(
      name: 'Ensure word is present',
      script: 'topic_required_words'
    )
  end

  before do
    automation.create_trigger!(name: 'topic', metadata: {})
  end

  context 'updating trigger' do
    it 'updates the custom field' do
      automation.trigger.update_with_params(metadata: { topic_id: topic.id })
      expect(topic.custom_fields['discourse_automation_id']).to eq(automation.id)

      new_topic = create_topic
      automation.trigger.update_with_params(metadata: { topic_id: new_topic.id })
      expect(new_topic.custom_fields['discourse_automation_id']).to eq(automation.id)
    end
  end
end
