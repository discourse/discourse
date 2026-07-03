# frozen_string_literal: true

RSpec.describe InviteSerializer do
  describe "#as_json" do
    fab!(:user)
    fab!(:viewer) { Fabricate(:user, trust_level: TrustLevel[2]) }
    fab!(:group)
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }

    it "hides sensitive fields without permission to see invite details" do
      invite =
        Fabricate(
          :invite,
          invited_by: user,
          description: "private invite note",
          custom_message: "private invite message",
        )

      json =
        InviteSerializer.new(
          invite,
          scope: Guardian.new(viewer),
          root: false,
          show_emails: true,
        ).as_json

      expect(json).not_to include(
        :invite_key,
        :link,
        :description,
        :email,
        :domain,
        :emailed,
        :max_redemptions_allowed,
        :redemption_count,
        :custom_message,
        :topics,
        :groups,
      )
    end

    it "filters topics by guardian visibility" do
      invite = Fabricate(:invite, invited_by: user)
      TopicInvite.create!(invite: invite, topic: private_topic)

      json = InviteSerializer.new(invite, scope: Guardian.new(user), root: false).as_json

      expect(json[:topics]).to eq([])
    end
  end

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
