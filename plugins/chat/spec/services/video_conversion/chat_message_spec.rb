# frozen_string_literal: true

RSpec.describe VideoConversion::BaseAdapter do
  before(:each) { SiteSetting.authorized_extensions = "mp4" }

  fab!(:user)
  fab!(:channel, :chat_channel)
  let!(:upload) { Fabricate(:video_upload, user: user) }
  let!(:chat_message) do
    # Create a chat message with video upload
    # The video will be processed and cooked into a video placeholder
    message = Fabricate(:chat_message, user: user, chat_channel: channel, uploads: [upload])
    # Manually set cooked content to simulate initial state with video placeholder
    # This mimics what happens when a video is first uploaded
    message.update!(cooked: <<~HTML)
        <div class="video-placeholder-container" data-video-src="#{upload.url}">
          <div class="video-placeholder">
            <div class="video-placeholder-error">
              <div class="video-placeholder-error-content">
                <span class="video-placeholder-error-text">Video processing...</span>
              </div>
            </div>
          </div>
        </div>
      HTML
    message
  end

  before do
    SiteSetting.video_conversion_service = "aws_mediaconvert"
    SiteSetting.mediaconvert_role_arn = "arn:aws:iam::123456789012:role/MediaConvertRole"
    SiteSetting.enable_s3_uploads = true
    SiteSetting.video_conversion_enabled = true
    Jobs.run_immediately!
  end

  describe "when video conversion completes" do
    let(:optimized_upload) do
      Fabricate(:upload, user: user, extension: "mp4", original_filename: "video_converted.mp4")
    end
    let(:optimized_video) do
      OptimizedVideo.create!(
        upload: upload,
        optimized_upload: optimized_upload,
        adapter: "aws_mediaconvert",
      )
    end

    it "rebakes chat messages and updates cooked content with optimized video URL" do
      optimized_video # Ensure optimized video is created
      original_cooked = chat_message.cooked.dup
      optimized_url = Discourse.store.cdn_url(optimized_upload.url)

      # Stub the cook method to return our cooked content with video placeholder
      # This simulates the initial cooked state before optimization
      allow(Chat::Message).to receive(:cook).and_return(original_cooked)

      adapter = described_class.new(upload)
      adapter.send(:update_posts_with_optimized_video, optimized_video)

      chat_message.reload
      expect(chat_message.cooked).not_to eq(original_cooked)

      # Verify the cooked content now contains the optimized video URL
      doc = Nokogiri::HTML5.fragment(chat_message.cooked)
      container = doc.css(".video-placeholder-container").first
      expect(container).to be_present
      expect(container["data-video-src"]).to eq(optimized_url)
      expect(container["data-original-video-src"]).to eq(upload.url)
    end

    it "includes optimized video in serialized chat message" do
      optimized_video

      # Reload message with associations
      message =
        Chat::Message.includes(uploads: { optimized_videos: :optimized_upload }).find_by(
          id: chat_message.id,
        )

      guardian = Guardian.new(user)
      serializer = Chat::MessageSerializer.new(message, scope: guardian, root: false)
      serialized = serializer.as_json

      upload_data = serialized[:uploads].find { |u| u[:id] == upload.id }
      expect(upload_data[:optimized_video]).to be_present
      expect(upload_data[:optimized_video][:url]).to eq(optimized_upload.url)
    end
  end
end
