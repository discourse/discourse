# frozen_string_literal: true

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

  describe "#status" do
    fab!(:user_status) { Fabricate(:user_status) }
    fab!(:user) { Fabricate(:user, user_status: user_status) }
    let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

    it "adds user status when enabled" do
      SiteSetting.enable_user_status = true

      json = serializer.as_json

      expect(json[:status]).to_not be_nil do |status|
        expect(status.description).to eq(user_status.description)
        expect(status.emoji).to eq(user_status.emoji)
      end
    end

    it "doesn't add user status when disabled" do
      SiteSetting.enable_user_status = false
      json = serializer.as_json
      expect(json.keys).not_to include :status
    end

    it "doesn't add expired user status" do
      SiteSetting.enable_user_status = true

      user.user_status.ends_at = 1.minutes.ago
      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json.keys).not_to include :status
    end

    it "doesn't return status if user doesn't have it set" do
      SiteSetting.enable_user_status = true

      user.clear_status!
      user.reload
      json = serializer.as_json

      expect(json.keys).not_to include :status
    end
  end
end
