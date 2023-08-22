# frozen_string_literal: true

RSpec.describe "Chat composer draft", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) do
    Fabricate(
      :chat_message,
      chat_channel: channel_1,
      message: "This is a message for draft and replies",
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when loading a channel with a draft" do
    fab!(:draft_1) do
      Chat::Draft.create!(
        chat_channel: channel_1,
        user: current_user,
        data: { message: "draft" }.to_json,
      )
    end

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "loads the draft" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.composer.value).to eq("draft")
    end

    context "when loading another channel and back" do
      fab!(:channel_2) { Fabricate(:chat_channel) }

      fab!(:draft_2) do
        Chat::Draft.create!(
          chat_channel: channel_2,
          user: current_user,
          data: { message: "draft2" }.to_json,
        )
      end

      before { channel_2.add(current_user) }

      it "loads the correct drafts" do
        chat_page.visit_channel(channel_1)

        expect(channel_page.composer.value).to eq("draft")

        chat_page.visit_channel(channel_2)

        expect(channel_page.composer.value).to eq("draft2")

        chat_page.visit_channel(channel_1)

        expect(channel_page.composer.value).to eq("draft")
      end
    end

    context "with editing" do
      fab!(:draft_1) do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: { message: message_1.message, id: message_1.id, editing: true }.to_json,
        )
      end

      it "loads the draft with the editing state" do
        chat_page.visit_channel(channel_1)

        expect(channel_page.composer).to be_editing_message(message_1)
      end

      context "when canceling editing" do
        it "resets the draft" do
          chat_page.visit_channel(channel_1)
          channel_page.composer.message_details.cancel_edit

          expect(channel_page.composer).to be_blank
          expect(channel_page.composer).to have_unsaved_draft
          expect(channel_page.composer).to have_saved_draft
        end
      end
    end

    context "with uploads" do
      fab!(:upload_1) do
        Fabricate(
          :upload,
          url: "/images/logo-dark.png",
          original_filename: "logo_dark.png",
          width: 400,
          height: 300,
          extension: "png",
        )
      end

      fab!(:draft_1) do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: { message: "draft", uploads: [upload_1] }.to_json,
        )
      end

      it "loads the draft with the upload" do
        chat_page.visit_channel(channel_1)

        expect(channel_page.composer.value).to eq("draft")
        expect(page).to have_selector(".chat-composer-upload--image", count: 1)
      end
    end

    context "when replying" do
      fab!(:draft_1) do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: {
            message: "draft",
            replyToMsg: {
              id: message_1.id,
              excerpt: message_1.excerpt,
              user: {
                id: message_1.user.id,
                name: nil,
                avatar_template: message_1.user.avatar_template,
                username: message_1.user.username,
              },
            },
          }.to_json,
        )
      end

      it "loads the draft with replied to mesage" do
        chat_page.visit_channel(channel_1)

        expect(channel_page.composer.value).to eq("draft")
        expect(page).to have_selector(".chat-reply__username", text: message_1.user.username)
        expect(page).to have_selector(".chat-reply__excerpt", text: message_1.excerpt)
      end
    end
  end
end
