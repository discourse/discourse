# frozen_string_literal: true

require 'rails_helper'

Automation ||= DiscourseAutomation::Automation
Trigger ||= DiscourseAutomation::Trigger

describe Jobs::DiscourseAutomationTracker do
  let!(:automation) {
    automation = Automation.create!(
      name: 'Secret Santa',
      script: 'gift_exchange'
    )

    automation.create_trigger!(
      name: Trigger::POINT_IN_TIME,
    )

    automation
  }

  before do
    freeze_time
  end

  context 'point in time' do
    context 'pending automation is in past' do
      before do
        automation.trigger.update_with_params(metadata: { execute_at: 2.hours.ago })
      end

      it 'consumes the pending automation' do
        expect(automation.pending_automations.count).to eq(1)

        Jobs::DiscourseAutomationTracker.new.execute

        expect(automation.pending_automations.count).to eq(0)
      end
    end

    context 'pending automation is in future' do
      before do
        automation.trigger.update_with_params(metadata: { execute_at: 2.hours.from_now })
      end

      it 'doesn’t consume the pending automation' do
        expect(automation.pending_automations.count).to eq(1)

        Jobs::DiscourseAutomationTracker.new.execute

        expect(automation.pending_automations.count).to eq(1)
      end
    end
  end
end
