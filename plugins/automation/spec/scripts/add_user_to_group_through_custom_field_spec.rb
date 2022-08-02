# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'AddUserTogroupThroughCustomField' do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::ADD_USER_TO_GROUP_THROUGH_CUSTOM_FIELD
    )
  end

  before do
    automation.upsert_field!('custom_field_name', 'text', { value: 'groupity_group' }, target: 'script')
  end

  context 'with no matching user custom fields' do
    it 'works' do
      expect(user1.groups).to be_empty
      expect(user2.groups).to be_empty

      automation.trigger!

      user1.reload
      user2.reload

      expect(user1.groups).to be_empty
      expect(user2.groups).to be_empty
    end
  end

  context 'with one matching user' do
    before do
      UserCustomField.create!(user_id: user1.id, name: 'groupity_group', value: group.name)
    end

    it 'works' do
      expect(user1.groups).to be_empty
      expect(user2.groups).to be_empty

      automation.trigger!

      user1.reload
      user2.reload

      expect(user1.groups.count).to eq(1)
      expect(user1.groups.first.name).to eq(group.name)

      expect(user2.groups).to be_empty
    end
  end

  context 'when group is already present' do
    before do
      group.add(user1)
    end

    it 'works' do
      expect(user1.groups.count).to eq(1)
      expect(user2.groups).to be_empty

      automation.trigger!

      user1.reload
      user2.reload

      expect(user1.groups.count).to eq(1)
      expect(user1.groups.first.name).to eq(group.name)

      expect(user2.groups).to be_empty
    end
  end

end
