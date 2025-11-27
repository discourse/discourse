# frozen_string_literal: true

RSpec.describe PostVoting::GuardianExtension do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:group)

  before { SiteSetting.post_voting_enabled = true }

  describe "#can_create_post_voting_topic?" do
    context "when user is nil" do
      it "returns false" do
        guardian = Guardian.new(nil)
        expect(guardian.can_create_post_voting_topic?).to eq(false)
      end
    end

    context "when user is staff" do
      it "returns true for admin" do
        guardian = Guardian.new(admin)
        expect(guardian.can_create_post_voting_topic?).to eq(true)
      end

      it "returns true for moderator" do
        guardian = Guardian.new(moderator)
        expect(guardian.can_create_post_voting_topic?).to eq(true)
      end
    end

    context "when user is in allowed groups" do
      before do
        group.add(user)
        SiteSetting.post_voting_create_allowed_groups = group.id.to_s
      end

      it "returns true" do
        guardian = Guardian.new(user)
        expect(guardian.can_create_post_voting_topic?).to eq(true)
      end
    end

    context "when user is not in allowed groups" do
      before { SiteSetting.post_voting_create_allowed_groups = group.id.to_s }

      it "returns false" do
        guardian = Guardian.new(user)
        expect(guardian.can_create_post_voting_topic?).to eq(false)
      end
    end

    context "with default setting (trust_level_1)" do
      before { SiteSetting.post_voting_create_allowed_groups = "11" }

      it "returns false for trust_level_0" do
        user.update!(trust_level: TrustLevel[0])
        user.groups.destroy_all
        Group.refresh_automatic_groups!
        guardian = Guardian.new(user)
        expect(guardian.can_create_post_voting_topic?).to eq(false)
      end

      it "returns true for trust_level_1" do
        user.update!(trust_level: TrustLevel[1])
        Group.refresh_automatic_groups!
        guardian = Guardian.new(user)
        expect(guardian.can_create_post_voting_topic?).to eq(true)
      end
    end
  end
end
