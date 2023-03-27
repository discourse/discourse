# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::InReplyToSerializer do
  subject(:serializer) { described_class.new(message, scope: guardian, root: nil) }

  fab!(:chat_channel) { Fabricate(:chat_channel) }
  let(:guardian) { Guardian.new(Fabricate(:user)) }

  describe "#user" do
    let(:message) { Fabricate(:chat_message, user: Fabricate(:user), chat_channel: chat_channel) }

    context "when user has been destroyed" do
      before do
        message.user.destroy!
        message.reload
      end

      it "returns a placeholder user" do
        expect(serializer.as_json[:user][:username]).to eq(I18n.t("chat.deleted_chat_username"))
      end
    end
  end

  describe "#excerpt" do
    let(:watched_word) { Fabricate(:watched_word, action: WatchedWord.actions[:censor]) }
    let(:message) { Fabricate(:chat_message, message: "ok #{watched_word.word}") }

    it "censors words" do
      expect(serializer.as_json[:excerpt]).to eq("ok ■■■■■")
    end
  end
end
