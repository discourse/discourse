# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'UserBadgeGranted' do
  fab!(:user) { Fabricate(:user) }
  fab!(:tracked_badge) { Fabricate(:badge) }
  fab!(:automation) {
    Fabricate(
      :automation,
      trigger: DiscourseAutomation::Triggerable::USER_BADGE_GRANTED
    )
  }

  before do
    SiteSetting.discourse_automation_enabled = true
    automation.upsert_field!('badge', 'choices', { value: tracked_badge.id }, target: 'trigger')
  end

  context 'a badge is granted' do
    it 'fires the trigger' do
      output = JSON.parse(capture_stdout do
        BadgeGranter.grant(tracked_badge, user)
      end)

      expect(output['kind']).to eq(DiscourseAutomation::Triggerable::USER_BADGE_GRANTED)
    end
  end
end
