# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe Jobs::DiscourseAutomationTracker do
  before do
    SiteSetting.discourse_automation_enabled = true
  end

  describe 'pending automation' do
    fab!(:automation) {
      Fabricate(
        :automation,
        script: 'gift_exchange',
        trigger: DiscourseAutomation::Triggerable::POINT_IN_TIME
      )
    }

    before do
      automation.upsert_field!('giftee_assignment_messages', 'pms', { value: [{ raw: 'foo', title: 'bar' }] }, target: 'script')
      automation.upsert_field!('gift_exchangers_group', 'group', { value: 1 }, target: 'script')
    end

    context 'pending automation is in past' do
      before do
        automation.upsert_field!('execute_at', 'date_time', { value: 2.hours.from_now }, target: 'trigger')
      end

      it 'consumes the pending automation' do
        freeze_time 4.hours.from_now do
          expect {
            Jobs::DiscourseAutomationTracker.new.execute
          }.to change {
            automation.pending_automations.count
          }.by(-1)
        end
      end
    end

    context 'pending automation is in future' do
      before do
        automation.upsert_field!('execute_at', 'date_time', { value: 2.hours.from_now }, target: 'trigger')
      end

      it 'doesn’t consume the pending automation' do
        expect {
          Jobs::DiscourseAutomationTracker.new.execute
        }.to change {
          automation.pending_automations.count
        }.by(0)
      end
    end
  end

  describe 'pending pms' do
    before do
      Jobs.run_later!
    end

    fab!(:automation) {
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scriptable::SEND_PMS,
        trigger: DiscourseAutomation::Triggerable::TOPIC
      )
    }

    let!(:pending_pm) {
      automation.pending_pms.create!(
        title: 'Il pleure dans mon cœur Comme il pleut sur la ville;',
        raw: 'Quelle est cette langueur Qui pénètre mon cœur ?',
        sender: 'system',
        execute_at: Time.now
      )
    }

    context 'pending pm is in past' do
      before do
        pending_pm.update!(execute_at: 2.hours.ago)
      end

      it 'consumes the pending pm' do
        expect {
          Jobs::DiscourseAutomationTracker.new.execute
        }.to change {
          automation.pending_pms.count
        }.by(-1)
      end
    end

    context 'pending pm is in future' do
      before do
        pending_pm.update!(execute_at: 2.hours.from_now)
      end

      it 'doesn’t consume the pending pm' do
        expect {
          Jobs::DiscourseAutomationTracker.new.execute
        }.to change {
          automation.pending_pms.count
        }.by(0)
      end
    end
  end
end
