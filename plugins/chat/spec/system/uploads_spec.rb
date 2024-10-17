# frozen_string_literal: true

describe "Uploading files in chat messages", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when uploading to a new message" do
    before do
      Jobs.run_immediately!
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "allows to drag files to start upload" do
      chat.visit_channel(channel_1)

      # Define the JavaScript to simulate dragging an external image
      page.execute_script(<<-JS)
        const target = document.querySelector('.chat-channel');
        const dataTransfer = new DataTransfer();
        const file = new File(['dummy content'], 'test-image.png', { type: 'image/png' });

        dataTransfer.items.add(file);

        const dragEnterEvent = new DragEvent('dragenter', { dataTransfer: dataTransfer });
        target.dispatchEvent(dragEnterEvent);

        const dragOverEvent = new DragEvent('dragover', { dataTransfer: dataTransfer });
        target.dispatchEvent(dragOverEvent);
      JS

      expect(find(".chat-upload-drop-zone__text__title")).to have_content(
        I18n.t("js.chat.upload_to_channel", { title: channel_1.title }),
      )
    end

    it "allows uploading a single file" do
      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("logo.png", "images").path

      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img")

      channel_page.send_message("upload testing")

      expect(page).to have_no_css(".chat-composer-upload")

      expect(channel_page.messages).to have_message(
        text: "upload testing\n#{File.basename(file_path)}",
        persisted: true,
      )

      expect(Chat::Message.last.uploads.count).to eq(1)
    end

    xit "adds a thumbnail for large images" do
      SiteSetting.create_thumbnails = true

      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("huge.jpg", "images").path

      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect { channel_page.send_message }.to change { Chat::Message.count }.by(1)

      expect(channel_page).to have_no_css(".chat-composer-upload")

      message = Chat::Message.last

      try_until_success(timeout: 5) { expect(message.uploads.first.thumbnail).to be_present }

      upload = message.uploads.first

      # image has src attribute with thumbnail url
      expect(channel_page).to have_css(".chat-uploads img[src$='#{upload.thumbnail.url}']")

      # image has data-large-src with original image src
      expect(channel_page).to have_css(".chat-uploads img[data-large-src$='#{upload.url}']")
    end

    it "adds dominant color attribute to images" do
      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("logo.png", "images").path

      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      channel_page.click_send_message

      expect(channel_page.messages).to have_css(".chat-img-upload[data-dominant-color]", count: 1)
    end

    it "allows uploading multiple files" do
      skip_on_ci!

      chat.visit_channel(channel_1)

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      attach_file([file_path_1, file_path_2]) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img", count: 2)
      channel_page.send_message("upload testing")

      expect(page).to have_no_css(".chat-composer-upload")
      expect(channel_page.messages).to have_message(
        text: "upload testing\n#{I18n.t("js.chat.uploaded_files", count: 2)}",
        persisted: true,
        wait: 5,
      )

      expect(Chat::Message.last.uploads.count).to eq(2)
    end

    it "allows uploading a huge image file with preprocessing" do
      skip_on_ci!

      SiteSetting.composer_media_optimization_image_bytes_optimization_threshold = 200.kilobytes
      chat.visit_channel(channel_1)
      file_path = file_from_fixtures("huge.jpg", "images").path

      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect(find(".chat-composer-upload")).to have_content("Processing")

      # image processing clientside is slow! here we are waiting for processing
      # to complete then the upload to complete as well
      expect(page).to have_css(".chat-composer-upload .preview .preview-img", wait: 25)

      channel_page.send_message("upload testing")

      expect(page).to have_no_css(".chat-composer-upload")

      expect(channel_page.messages).to have_message(
        text: "upload testing\n#{File.basename(file_path)}",
        persisted: true,
      )

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
      channel_page.messages.edit(message_2)
      find(".chat-composer-upload").hover
      find(".chat-composer-upload__remove-btn").click
      expect(channel_page.message_by_id(message_2.id)).to have_no_css(".chat-uploads")

      channel_page.click_send_message
      try_until_success(timeout: 5) { expect(message_2.reload.upload_ids).to be_empty }
    end

    it "allows adding more uploads" do
      chat.visit_channel(channel_1)
      channel_page.messages.edit(message_2)

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload .preview .preview-img", count: 2)

      channel_page.click_send_message

      expect(page).to have_no_css(".chat-composer-upload")
      expect(page).to have_css(".chat-img-upload", count: 2)

      try_until_success(timeout: 5) { expect(message_2.reload.uploads.count).to eq(2) }
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
      channel_page.open_action_menu
      expect(page).to have_no_css(".chat-upload-btn")
    end

    it "does not show the action button for uploading files in direct message channels" do
      chat.visit_channel(direct_message_channel_1)
      channel_page.open_action_menu
      expect(page).to have_no_css(".chat-upload-btn")
    end
  end
end
