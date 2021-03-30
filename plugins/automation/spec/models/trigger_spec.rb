# frozen_string_literal: true

require 'rails_helper'

Trigger ||= DiscourseAutomation::Trigger
Automation ||= DiscourseAutomation::Automation
PendingAutomation ||= DiscourseAutomation::PendingAutomation

describe DiscourseAutomation::Trigger do
  before do
    freeze_time
  end

  let(:automation) {
    Automation.create!(
      name: 'Secret Santa',
      script: 'gift_exchange'
    )
  }

  context 'point in time' do
    describe '#update_with_params' do
      it 'creates a pending automation' do
        expect(automation.pending_automations.count).to eq(0)

        trigger = automation.create_trigger!(
          name: DiscourseAutomation::Triggerable::POINT_IN_TIME
        )
        trigger.update_with_params(metadata: { execute_at: 2.hours.from_now })

        expect(automation.pending_automations.count).to eq(1)
      end

      it 'destroys previous pending automation' do
        trigger = automation.create_trigger(
          name: DiscourseAutomation::Triggerable::POINT_IN_TIME
        )
        trigger.update_with_params(metadata: { execute_at: 2.hours.from_now })

        expect(automation.pending_automations.first.execute_at).to eq_time(2.hours.from_now)

        trigger.update_with_params(metadata: { execute_at: 3.hours.from_now })

        expect(automation.pending_automations.count).to eq(1)
        expect(automation.pending_automations.first.execute_at).to eq_time(3.hours.from_now)
      end
    end
  end
end
