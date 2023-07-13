# frozen_string_literal: true

require "rails_helper"

describe Chat::DirectMessageSerializer do
  describe "#user" do
    it "returns you when there are two of us" do
      me = Fabricate.build(:user)
      you = Fabricate.build(:user)
      direct_message = Fabricate.build(:direct_message, users: [me, you])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)

      expect(serializer.users).to eq([you])
    end

    it "returns you both if there are three of us" do
      me = Fabricate.build(:user)
      you = Fabricate.build(:user)
      other_you = Fabricate.build(:user)
      direct_message = Fabricate.build(:direct_message, users: [me, you, other_you])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)

      expect(serializer.users).to match_array([you, other_you])
    end

    it "returns me if there is only me" do
      me = Fabricate.build(:user)
      direct_message = Fabricate.build(:direct_message, users: [me])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)

      expect(serializer.users).to eq([me])
    end

    context "when a user is destroyed" do
      it "returns a placeholder user" do
        me = Fabricate(:user)
        you = Fabricate(:user)
        direct_message = Fabricate(:direct_message, users: [me, you])

        you.destroy!

        serializer =
          described_class.new(direct_message.reload, scope: Guardian.new(me), root: false).as_json

        expect(serializer[:users][0][:username]).to eq(I18n.t("chat.deleted_chat_username"))
      end
    end
  end
end
