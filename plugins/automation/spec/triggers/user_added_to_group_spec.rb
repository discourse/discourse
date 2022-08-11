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
      list = capture_contexts do
        tracked_group.add(user)
      end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq('user_added_to_group')
    end
  end

  context 'group is not tracked' do
    let(:untracked_group) { Fabricate(:group) }

    it 'doesn’t fire the trigger' do
      list = capture_contexts do
        untracked_group.add(user)
      end

      expect(list).to eq([])
    end
  end
end
