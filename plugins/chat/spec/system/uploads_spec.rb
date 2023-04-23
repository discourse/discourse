# frozen_string_literal: true

describe "Uploading files in chat messages", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when uploading to a new message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "allows uploading a single file" do
      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) do
        channel.open_action_menu
        channel.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img")
      expect(page).to have_content(File.basename(file_path))

      channel.send_message("upload testing")

      expect(page).not_to have_css(".chat-composer-upload")
      expect(channel).to have_message(text: "upload testing")
      expect(Chat::Message.last.uploads.count).to eq(1)
    end

    it "allows uploading multiple files" do
      chat.visit_channel(channel_1)

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      attach_file([file_path_1, file_path_2]) do
        channel.open_action_menu
        channel.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img", count: 2)
      channel.send_message("upload testing")

      expect(page).not_to have_css(".chat-composer-upload")
      expect(channel).to have_message(text: "upload testing")
      expect(Chat::Message.last.uploads.count).to eq(2)
    end

    it "allows uploading a huge image file with preprocessing" do
      SiteSetting.composer_media_optimization_image_bytes_optimization_threshold = 200.kilobytes
      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("huge.jpg", "images").path
      attach_file(file_path) do
        channel.open_action_menu
        channel.click_action_button("chat-upload-btn")
      end

      expect(page).to have_content(File.basename(file_path))
      expect(find(".chat-composer-upload")).to have_content("Processing")

      # image processing clientside is slow! here we are waiting for processing
      # to complete then the upload to complete as well
      using_wait_time(10) do
        expect(find(".chat-composer-upload")).to have_content("Uploading")
        expect(page).to have_css(".chat-composer-upload .preview .preview-img")
      end

      channel.send_message("upload testing")

      expect(page).not_to have_css(".chat-composer-upload")
      expect(channel).to have_message(text: "upload testing")
      expect(Chat::Message.last.uploads.count).to eq(1)
    end
  end

  context "when editing a message with uploads" do
    fab!(:message_2) { Fabricate(:chat_message, user: current_user, chat_channel: channel_1) }
    fab!(:upload_reference) do
      Fabricate(
        :upload_reference,
        target: message_2,
        upload: Fabricate(:upload, user: current_user),
      )
    end

    before do
      channel_1.add(current_user)
      sign_in(current_user)

      file = file_from_fixtures("logo-dev.png", "images")
      url = Discourse.store.store_upload(file, upload_reference.upload)
      upload_reference.upload.update!(url: url, sha1: Upload.generate_digest(file))
    end

    it "allows deleting uploads" do
      chat.visit_channel(channel_1)
      channel.open_edit_message(message_2)
      find(".chat-composer-upload").hover
      find(".chat-composer-upload__remove-btn").click
      channel.click_send_message
      expect(channel.message_by_id(message_2.id)).not_to have_css(".chat-uploads")
      expect(message_2.reload.uploads).to be_empty
    end

    it "allows adding more uploads" do
      chat.visit_channel(channel_1)
      channel.open_edit_message(message_2)

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) do
        channel.open_action_menu
        channel.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img", count: 2)
      expect(page).to have_content(File.basename(file_path))

      channel.click_send_message

      expect(page).not_to have_css(".chat-composer-upload")
      expect(page).to have_css(".chat-img-upload", count: 2)
      expect(message_2.reload.uploads.count).to eq(2)
    end
  end

  context "when uploads are not allowed" do
    fab!(:user_2) { Fabricate(:user) }
    fab!(:direct_message_channel_1) do
      Fabricate(:direct_message_channel, users: [current_user, user_2])
    end

    before do
      SiteSetting.chat_allow_uploads = false
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "does not show the action button for uploading files in public channels" do
      chat.visit_channel(channel_1)
      channel.open_action_menu
      expect(page).not_to have_css(".chat-upload-btn")
    end

    it "does not show the action button for uploading files in direct message channels" do
      chat.visit_channel(direct_message_channel_1)
      channel.open_action_menu
      expect(page).not_to have_css(".chat-upload-btn")
    end
  end
end
