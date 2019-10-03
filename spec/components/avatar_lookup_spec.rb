# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe AvatarLookup do
  fab!(:user) { Fabricate(:user, username: "john_doe", name: "John Doe") }

  describe '#[]' do
    before do
      @avatar_lookup = AvatarLookup.new([user.id, nil])
    end

    it 'returns nil if user_id does not exists' do
      expect(@avatar_lookup[0]).to eq(nil)
    end

    it 'returns nil if user_id is nil' do
      expect(@avatar_lookup[nil]).to eq(nil)
    end

    it 'returns user if user_id exists' do
      avatar_lookup_user = @avatar_lookup[user.id]
      expect(avatar_lookup_user).to eq(user)
      expect(avatar_lookup_user.username).to eq("john_doe")
      expect(avatar_lookup_user.name).to eq("John Doe")
    end
  end
end
