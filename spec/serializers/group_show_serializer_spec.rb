# frozen_string_literal: true

require 'rails_helper'

describe GroupShowSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  context 'admin user' do
    fab!(:user) { Fabricate(:admin) }
    fab!(:group) { Fabricate(:group, users: [user]) }

    it 'should return the right attributes' do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(true)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end

  context 'group owner' do
    before do
      group.add_owner(user)
    end

    it 'should return the right attributes' do
      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:is_group_owner]).to eq(true)
      expect(json[:group_show][:is_group_user]).to eq(true)
    end
  end

  describe '#mentionable' do
    fab!(:group) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }

    it 'should return the right value' do
      json = GroupShowSerializer.new(group, scope: Guardian.new).as_json

      expect(json[:group_show][:mentionable]).to eq(nil)

      json = GroupShowSerializer.new(group, scope: Guardian.new(user)).as_json

      expect(json[:group_show][:mentionable]).to eq(true)
    end
  end
end
