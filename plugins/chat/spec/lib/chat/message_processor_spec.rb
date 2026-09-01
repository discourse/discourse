# frozen_string_literal: true

RSpec.describe Chat::MessageProcessor do
  fab!(:message, :chat_message)

  it "cooks using the last_editor_id of the message" do
    Chat::Message.expects(:cook).with(
      message.message,
      user_id: message.last_editor_id,
      author_username: message.user.username,
    )
    described_class.new(message)
  end

  it "passes invalidate_oneboxes option to cook" do
    Chat::Message.expects(:cook).with(
      message.message,
      user_id: message.last_editor_id,
      author_username: message.user.username,
      invalidate_oneboxes: true,
    )
    described_class.new(message, invalidate_oneboxes: true)
  end

  describe "#run!" do
    it "processes messages with hotlinked images in oneboxes without errors" do
      # Create a message with an image in a onebox (common when posting URLs with images)
      cooked_html = <<~HTML
        <aside class="onebox">
          <img src="https://example.com/image.jpg" width="500" height="300">
        </aside>
      HTML

      Chat::Message.stubs(:cook).returns(cooked_html)
      processor = described_class.new(message)

      # This should not raise an error even though @post is nil
      expect { processor.run! }.not_to raise_error
    end
  end

  describe "#process_hotlinked_image" do
    fab!(:upload) { Fabricate(:upload, width: 100, height: 100, extension: "gif") }
    let(:image_url) { "http://example.com/image.gif" }

    def create_downloaded_record(chat_message)
      Chat::MessageHotlinkedMedia.create!(
        chat_message: chat_message,
        url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
        status: :downloaded,
        upload: upload,
      )
    end

    it "swaps a downloaded external img src for the local upload" do
      create_downloaded_record(message)
      Chat::Message.stubs(:cook).returns("<p><img src=\"#{image_url}\"></p>")

      processor = described_class.new(message)
      processor.run!

      img = processor.instance_variable_get(:@doc).at_css("img")
      expect(img["src"]).to eq(UrlHelper.cook_url(upload.url, secure: false))
      expect(img["data-base62-sha1"]).to eq(upload.base62_sha1)
      expect(img["class"]).to include("lightbox")
    end

    it "swaps an image inside a onebox without lightboxing it" do
      create_downloaded_record(message)
      Chat::Message.stubs(:cook).returns(
        "<aside class=\"onebox\"><img src=\"#{image_url}\" width=\"100\" height=\"100\"></aside>",
      )

      processor = described_class.new(message)
      processor.run!

      img = processor.instance_variable_get(:@doc).at_css("img")
      expect(img["src"]).to eq(UrlHelper.cook_url(upload.url, secure: false))
      expect(img["class"].to_s).not_to include("lightbox")
    end

    context "with secure uploads enabled" do
      before do
        setup_s3
        SiteSetting.secure_uploads = true
      end

      it "localizes to the secure proxy URL when the upload is secure" do
        secure_upload = Fabricate(:secure_upload_s3, width: 100, height: 100)
        secure_upload.update_columns(dominant_color: "000000")
        Chat::MessageHotlinkedMedia.create!(
          chat_message: message,
          url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
          status: :downloaded,
          upload: secure_upload,
        )
        Chat::Message.stubs(:cook).returns("<p><img src=\"#{image_url}\"></p>")

        processor = described_class.new(message)
        processor.run!

        img = processor.instance_variable_get(:@doc).at_css("img")
        expect(img["src"]).to include("secure-uploads")
        expect(img["src"]).not_to include("s3-upload-bucket")
      end
    end

    it "clears both blocked-hotlinked attributes once the image is localized" do
      create_downloaded_record(message)
      Chat::Message.stubs(:cook).returns(<<~HTML)
        <p><img #{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}="#{image_url}" #{PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR}="#{image_url} 2x"></p>
      HTML

      processor = described_class.new(message)
      processor.run!

      img = processor.instance_variable_get(:@doc).at_css("img")
      expect(img["src"]).to eq(UrlHelper.cook_url(upload.url, secure: upload.secure?))
      expect(img[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR]).to be_nil
      expect(img[PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR]).to be_nil
    end

    it "leaves the hotlinked src for failed or oversized downloads" do
      Chat::MessageHotlinkedMedia.create!(
        chat_message: message,
        url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
        status: :too_large,
      )
      Chat::Message.stubs(:cook).returns("<p><img src=\"#{image_url}\"></p>")

      processor = described_class.new(message)
      processor.run!

      img = processor.instance_variable_get(:@doc).at_css("img")
      expect(img["src"]).to eq(image_url)
    end
  end

  describe "#add_lightbox_to_images" do
    fab!(:upload) { Fabricate(:upload, width: 800, height: 600) }
    let(:base62) { Upload.base62_sha1(upload.sha1) }

    it "adds lightbox class to quoted images" do
      cooked_html = <<~HTML
      <blockquote>
        <img src="#{upload.url}" width="500" height="300" data-base62-sha1="#{base62}">
      </blockquote>
    HTML

      Chat::Message.stubs(:cook).returns(cooked_html)
      processor = described_class.new(message)

      processor.run!

      doc = processor.instance_variable_get(:@doc)
      img = doc.at_css("img")

      expect(img["class"]).to include("lightbox")
      expect(img["data-large-src"]).to eq(UrlHelper.cook_url(upload.url, secure: upload.secure?))
      expect(img["data-download-href"]).to eq(upload.short_path)
      expect(img["data-target-width"]).to eq(upload.width.to_s)
      expect(img["data-target-height"]).to eq(upload.height.to_s)
    end

    it "does not lightbox an image the onebox engine already wrapped" do
      cooked_html =
        "<p><img class=\"onebox\" src=\"#{upload.url}\" data-base62-sha1=\"#{base62}\"></p>"

      Chat::Message.stubs(:cook).returns(cooked_html)
      processor = described_class.new(message)

      processor.run!

      img = processor.instance_variable_get(:@doc).at_css("img")
      expect(img["class"]).not_to include("lightbox")
    end

    context "with secure uploads enabled" do
      before do
        setup_s3
        SiteSetting.secure_uploads = true
      end

      it "uses the secure proxy URL for data-large-src" do
        secure_upload = Fabricate(:secure_upload_s3, width: 800, height: 600)
        secure_base62 = Upload.base62_sha1(secure_upload.sha1)
        secure_url = Upload.secure_uploads_url_from_upload_url(secure_upload.url)
        cooked_html = <<~HTML
          <p>
            <img src="#{secure_url}" width="500" height="300" data-base62-sha1="#{secure_base62}">
          </p>
        HTML

        Chat::Message.stubs(:cook).returns(cooked_html)
        processor = described_class.new(message)

        processor.run!

        doc = processor.instance_variable_get(:@doc)
        img = doc.at_css("img")

        expect(img["data-large-src"]).not_to include("s3-upload-bucket")
        expect(img["data-large-src"]).to include("secure-uploads")
      end
    end
  end
end
