# encoding: utf-8

require 'spec_helper'
require_dependency 'avatar_lookup'

describe AvatarLookup do
  let!(:user){ Fabricate(:user) }
  user_ids = [1, 2]

  describe '#new' do
    before do
      AvatarLookup.stubs(:filtered_users).once.returns(user_ids)
      @avatar_lookup = AvatarLookup.new
    end

    it 'init with cleaned user ids' do
      @avatar_lookup.user_ids.should eq(user_ids)
    end

    it 'init users hash' do
      @avatar_lookup.users.should eq(nil)
    end
  end

  describe '#[]' do
    before do
      @avatar_lookup = AvatarLookup.new([user.id])
    end

    it 'returns nil if user_id does not exists' do
      @avatar_lookup[0].should be_nil
    end

    it 'returns nil if user_id is nil' do
      @avatar_lookup[nil].should be_nil
    end

    it 'returns user if user_id exists' do
      @avatar_lookup[user.id].should eq(user)
    end
  end

  describe '.filtered_users' do
    it 'returns empty array if no params' do
      AvatarLookup.filtered_users.should eq([])
    end

    it 'returns empty array' do
      AvatarLookup.filtered_users([]).should eq([])
    end

    it 'returns filtered ids' do
      AvatarLookup.filtered_users(user_ids).should eq(user_ids)
    end

    it 'returns flatten filtered ids' do
      AvatarLookup.filtered_users([1, [2]]).should eq(user_ids)
    end

    it 'returns compact filtered ids' do
      AvatarLookup.filtered_users([1, 2, nil]).should eq(user_ids)
    end

    it 'returns uniq filtered ids' do
      AvatarLookup.filtered_users([1, 2, 2]).should eq(user_ids)
    end
  end

  describe '.hashed_users' do
    it 'returns empty hash if no params' do
      AvatarLookup.hashed_users.should eq({})
    end

    it 'returns hashed users by id' do
      AvatarLookup.hashed_users([user.id]).should eq({user.id => user})
    end
  end
end