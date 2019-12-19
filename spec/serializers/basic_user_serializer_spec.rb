# frozen_string_literal: true

require 'rails_helper'

describe BasicUserSerializer do
  describe '#as_json' do
    let(:user) { Fabricate.build(:user) }
    let(:serializer) { BasicUserSerializer.new(user, scope: Guardian.new(user), root: false) }
    let(:json) { serializer.as_json }

    it "returns the username" do
      expect(json[:username]).to eq(user.username)
      expect(json[:name]).to eq(user.name)
      expect(json[:avatar_template]).to eq(user.avatar_template)
    end

    describe 'extended serializers' do
      let(:post_action) { Fabricate(:post_action, user: user) }
      let(:serializer) { PostActionUserSerializer.new(post_action, scope: Guardian.new(user), root: false) }
      it "returns the user correctly" do
        expect(serializer.user.username).to eq(user.username)
      end
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to eq(nil)
    end
  end
end
