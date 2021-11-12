# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::AutomationSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:automation) {
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::FLAG_POST_ON_WORDS,
      trigger: DiscourseAutomation::Triggerable::POST_CREATED_EDITED
    )
  }

  context 'has pending automations' do
    before do
      automation.pending_automations.create!(execute_at: 2.hours.from_now)
    end

    it 'has a next_pending_automation_at field' do
      serializer = DiscourseAutomation::AutomationSerializer.new(automation, scope: Guardian.new(user), root: false)
      expect(serializer.next_pending_automation_at).to be_within_one_minute_of(2.hours.from_now)
    end
  end

  context 'has no pending automation' do
    it 'doesn’t have a next_pending_automation_at field' do
      serializer = DiscourseAutomation::AutomationSerializer.new(automation, scope: Guardian.new(user), root: false)
      expect(serializer.next_pending_automation_at).to_not be
    end
  end

  context 'script with fields limited to a specific trigger' do
    before do
      DiscourseAutomation::Scriptable.add('foo') do
        field :bar, component: :text, triggerable: DiscourseAutomation::Triggerable::TOPIC
      end
    end

    context 'automation is not using the specific trigger' do
      fab!(:automation) do
        Fabricate(
          :automation,
          script: 'foo',
          trigger: DiscourseAutomation::Triggerable::POST_CREATED_EDITED
        )
      end

      it 'filters the field' do
        serializer = DiscourseAutomation::AutomationSerializer.new(automation, scope: Guardian.new(user), root: false)
        expect(serializer.script[:templates]).to eq([])
      end
    end

    context 'automation is using the specific trigger' do
      fab!(:automation) do
        Fabricate(
          :automation,
          script: 'foo',
          trigger: DiscourseAutomation::Triggerable::TOPIC
        )
      end

      it 'doesn’t filter the field' do
        serializer = DiscourseAutomation::AutomationSerializer.new(automation, scope: Guardian.new(user), root: false)
        expect(serializer.script[:templates].length).to eq(1)
        expect(serializer.script[:templates].first[:name]).to eq(:bar)
      end
    end
  end
end
