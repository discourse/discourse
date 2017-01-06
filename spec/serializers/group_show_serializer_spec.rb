require 'rails_helper'

describe GroupShowSerializer do
  context 'admin user' do
    let(:user) { Fabricate(:admin) }
    let(:group) { Fabricate(:group, users: [user]) }

    it 'should return the right attributes' do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(true)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end

  context 'group owner' do
    let(:user) { Fabricate(:user) }
    let(:group) { Fabricate(:group) }

    before do
      group.add_owner(user)
    end

    it 'should return the right attributes' do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(true)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end
end
