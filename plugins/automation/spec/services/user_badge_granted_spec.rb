# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::UserBadgeGrantedHandler do
  fab!(:user) { Fabricate(:user) }
  fab!(:automation) {
    Fabricate(
      :automation,
      trigger: DiscourseAutomation::Triggerable::USER_BADGE_GRANTED
    )
  }

  before do
    SiteSetting.discourse_automation_enabled = true
  end

  context 'badge is not tracked' do
    fab!(:tracked_badge) { Fabricate(:badge) }

    it 'doesn’t trigger the automation' do
      output = capture_stdout do
        described_class.handle(automation, tracked_badge.id, user.id)
      end
      expect(output).to be_blank
    end
  end

  context 'badge is tracked' do
    fab!(:tracked_badge) { Fabricate(:badge) }

    before do
      automation.upsert_field!('badge', 'choices', { value: tracked_badge.id }, target: 'trigger')
    end

    context 'only trigger on first grant' do
      before do
        automation.upsert_field!('only_first_grant', 'boolean', { value: true }, target: 'trigger')
      end

      context 'badge has been granted already' do
        fab!(:tracked_badge) { Fabricate(:badge, grant_count: 2) }

        it 'doesn’t trigger the automation' do
          output = capture_stdout do
            described_class.handle(automation, tracked_badge.id, user.id)
          end
          expect(output).to be_blank
        end
      end

      context 'badge has not been granted already' do
        fab!(:tracked_badge) { Fabricate(:badge, grant_count: 1) }

        it 'triggers the automation' do
          output = JSON.parse(capture_stdout do
            described_class.handle(automation, tracked_badge.id, user.id)
          end)
          expect(output['kind']).to eq(DiscourseAutomation::Triggerable::USER_BADGE_GRANTED)
        end
      end

      context 'user doesn’t exist' do
        fab!(:tracked_badge) { Fabricate(:badge, grant_count: 1) }

        it 'raises an error' do
          expect {
            described_class.handle(automation, tracked_badge.id, -999)
          }.to raise_error(ActiveRecord::RecordNotFound, /'id'=-999/)
        end
      end
    end

    it 'triggers the automation' do
      output = JSON.parse(capture_stdout do
        described_class.handle(automation, tracked_badge.id, user.id)
      end)

      expect(output['kind']).to eq(DiscourseAutomation::Triggerable::USER_BADGE_GRANTED)
      expect(output['usernames']).to eq([user.username])
      expect(output['placeholders']).to eq('badge_name' => tracked_badge.name, 'grant_count' => tracked_badge.grant_count)
      expect(output['badge']['id']).to eq(tracked_badge.id)
    end
  end
end
