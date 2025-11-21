# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before { SiteSetting.post_voting_enabled = true }

  describe "#can_create_post_voting_topic" do
    it "is included in serialized output" do
      serializer = CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json.key?(:can_create_post_voting_topic)).to eq(true)
    end

    context "when user is in allowed groups" do
      before do
        group.add(user)
        SiteSetting.post_voting_create_allowed_groups = group.id.to_s
      end

      it "returns true" do
        serializer = CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
        json = serializer.as_json

        expect(json[:can_create_post_voting_topic]).to eq(true)
      end
    end

    context "when user is not in allowed groups" do
      before { SiteSetting.post_voting_create_allowed_groups = group.id.to_s }

      it "returns false" do
        serializer = CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
        json = serializer.as_json

        expect(json[:can_create_post_voting_topic]).to eq(false)
      end
    end

    context "when user is staff" do
      it "returns true" do
        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin), root: false)
        json = serializer.as_json

        expect(json[:can_create_post_voting_topic]).to eq(true)
      end
    end
  end
end
