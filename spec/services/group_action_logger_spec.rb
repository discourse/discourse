require 'rails_helper'

RSpec.describe GroupActionLogger do
  let(:group_owner) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }

  subject { described_class.new(group_owner, group) }

  before do
    group.add_owner(group_owner)
  end

  describe '#log_make_user_group_owner' do
    it 'should create the right record' do
      subject.log_make_user_group_owner(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:make_user_group_owner])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe '#log_remove_user_as_group_owner' do
    it 'should create the right record' do
      subject.log_remove_user_as_group_owner(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:remove_user_as_group_owner])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe '#log_add_user_to_group' do
    it 'should create the right record' do
      subject.log_add_user_to_group(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe '#log_remove_user_from_group' do
    it 'should create the right record' do
      subject.log_remove_user_from_group(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:remove_user_from_group])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe '#log_change_group_settings' do
    it 'should create the right record' do
      group.update_attributes!(public: true, created_at: Time.zone.now)

      expect { subject.log_change_group_settings }.to change { GroupHistory.count }.by(1)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:change_group_setting])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.subject).to eq('public')
      expect(group_history.prev_value).to eq('f')
      expect(group_history.new_value).to eq('t')
    end
  end
end
