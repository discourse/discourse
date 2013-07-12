# encoding: utf-8

require 'spec_helper'
require_dependency 'avatar_lookup'

describe AvatarLookup do
  let!(:user){ Fabricate(:user) }

  describe '#[]' do
    before do
      @avatar_lookup = AvatarLookup.new([user.id, nil])
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
end