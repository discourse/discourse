# frozen_string_literal: true

RSpec.describe InviteSerializer do
  describe "#can_delete_invite" do
    fab!(:user)
    fab!(:admin)
    fab!(:moderator)
    fab!(:invite_from_user) { Fabricate(:invite, invited_by: user) }
    fab!(:invite_from_moderator) { Fabricate(:invite, invited_by: moderator) }

    it "returns true for admin" do
      serializer = InviteSerializer.new(invite_from_user, scope: Guardian.new(admin), root: false)

      expect(serializer.as_json[:can_delete_invite]).to eq(true)
    end

    it "returns false for moderator" do
      serializer =
        InviteSerializer.new(invite_from_user, scope: Guardian.new(moderator), root: false)

      expect(serializer.as_json[:can_delete_invite]).to eq(false)
    end

    it "returns true for inviter" do
      serializer = InviteSerializer.new(invite_from_user, scope: Guardian.new(user), root: false)

      expect(serializer.as_json[:can_delete_invite]).to eq(true)
    end

    it "returns false for plain user" do
      serializer =
        InviteSerializer.new(invite_from_moderator, scope: Guardian.new(user), root: false)

      expect(serializer.as_json[:can_delete_invite]).to eq(false)
    end
  end
end
