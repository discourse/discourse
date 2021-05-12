# frozen_string_literal: true

require 'rails_helper'

describe 'USER_ADDED_TO_GROUP' do
  before do
    DiscourseAutomation::Scriptable.add('welcome_to_group') do
      version 1

      script do
        p 'Howdy!'
      end
    end
  end

  let(:user) { Fabricate(:user) }
  let(:tracked_group) { Fabricate(:group) }
  let!(:automation) {
    DiscourseAutomation::Automation.create!(
      name: 'Welcoming new users',
      script: 'welcome_to_group',
      last_updated_by_id: Discourse.system_user.id
    )
  }
  let!(:trigger) {
    automation.create_trigger!(name: 'user_added_to_group', metadata: { group_ids: [tracked_group.id] })
  }

  context 'group is tracked' do
    it 'fires the trigger' do
      output = capture_stdout do
        tracked_group.add(user)
      end

      expect(output).to include('Howdy!')
    end
  end

  context 'group is not tracked' do
    let(:untracked_group) { Fabricate(:group) }

    it 'doesn’t fire the trigger' do
      output = capture_stdout do
        untracked_group.add(user)
      end

      expect(output).to_not include('Howdy!')
    end
  end
end
