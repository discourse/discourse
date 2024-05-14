# frozen_string_literal: true

RSpec.describe Chat::InReplyToSerializer do
  subject(:serializer) { described_class.new(message, scope: guardian, root: nil) }

  fab!(:chat_channel)
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
    let(:message) do
      Fabricate(:chat_message, use_service: true, message: "ok #{watched_word.word}")
    end

    it "censors words" do
      expect(serializer.as_json[:excerpt]).to eq("ok ■■■■■")
    end

    it "builds an excerpt for replied to message if it doesn’t have one" do
      message.update!(excerpt: nil)
      expect(serializer.as_json[:excerpt]).to eq(message.build_excerpt)
    end
  end
end
