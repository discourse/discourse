# frozen_string_literal: true

require "rails_helper"

describe Chat::DirectMessageSerializer do
  describe "#memberships" do
    it "returns memberships" do
      me = Fabricate.build(:user)
      you = Fabricate.build(:user)
      other_you = Fabricate.build(:user)
      channel =
        Fabricate(:direct_message_channel, users: [me, you, other_you], with_membership: true)

      serializer = described_class.new(channel, scope: Guardian.new(me), root: false)

      expect(serializer.memberships.map(&:user)).to match_array([me, you, other_you])
    end

    context "when a user is destroyed" do
      it "is not in memberships" do
        me = Fabricate(:user)

        channel = Fabricate(:direct_message_channel, users: [me], with_membership: true)

        me.destroy!

        serializer =
          described_class.new(channel.reload, scope: Guardian.new(me), root: false).as_json
        expect(serializer[:memberships]).to be_empty
      end
    end
  end
end
