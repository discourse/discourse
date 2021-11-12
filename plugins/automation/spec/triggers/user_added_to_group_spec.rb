# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'UserAddedToGroup' do
  fab!(:user) { Fabricate(:user) }
  fab!(:tracked_group) { Fabricate(:group) }
  fab!(:automation) {
    Fabricate(
      :automation,
      trigger: DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP
    )
  }

  before do
    SiteSetting.discourse_automation_enabled = true
    automation.upsert_field!('joined_group', 'group', { value: tracked_group.id }, target: 'trigger')
  end

  context 'group is tracked' do
    it 'fires the trigger' do
      output = capture_stdout do
        tracked_group.add(user)
      end

      expect(output).to include('"kind":"user_added_to_group"')
    end
  end

  context 'group is not tracked' do
    let(:untracked_group) { Fabricate(:group) }

    it 'doesn’t fire the trigger' do
      output = capture_stdout do
        untracked_group.add(user)
      end

      expect(output).to_not include('"kind":"user_added_to_group"')
    end
  end
end
