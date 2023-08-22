# frozen_string_literal: true

require "rails_helper"

describe Chat::DeletedUser do
  subject(:deleted_user) { described_class.new }

  describe "#username" do
    it "returns a default username" do
      expect(deleted_user.username).to eq(I18n.t("chat.deleted_chat_username"))
    end
  end

  describe "#avatar_template" do
    it "returns a default path" do
      expect(deleted_user.avatar_template).to eq(
        "/plugins/chat/images/deleted-chat-user-avatar.png",
      )
    end
  end
end
