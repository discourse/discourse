# frozen_string_literal: true

describe Chat::DirectMessageSerializer do
  describe "#user" do
    it "returns you when there are two of us" do
      me = Fabricate(:user)
      you = Fabricate(:user)
      direct_message = Fabricate(:direct_message, users: [me, you])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)
      json = serializer.as_json

      expect(json[:users].map { |u| u[:username] }).to eq([you.username])
    end

    it "returns you both if there are three of us" do
      me = Fabricate(:user)
      you = Fabricate(:user)
      other_you = Fabricate(:user)
      direct_message = Fabricate(:direct_message, users: [me, you, other_you])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)
      json = serializer.as_json

      expect(json[:users].map { |u| u[:username] }).to match_array(
        [you.username, other_you.username],
      )
    end

    it "returns me if there is only me" do
      me = Fabricate(:user)
      direct_message = Fabricate(:direct_message, users: [me])

      serializer = described_class.new(direct_message, scope: Guardian.new(me), root: false)
      json = serializer.as_json

      expect(json[:users].map { |u| u[:username] }).to eq([me.username])
    end

    context "when a user is destroyed" do
      it "returns a placeholder user" do
        me = Fabricate(:user)
        you = Fabricate(:user)
        direct_message = Fabricate(:direct_message, users: [me, you])

        you.destroy!

        serializer =
          described_class.new(direct_message.reload, scope: Guardian.new(me), root: false)
        json = serializer.as_json

        expect(json[:users][0][:username]).to eq(I18n.t("chat.deleted_chat_username"))
      end
    end
  end
end
