# frozen_string_literal: true

RSpec.describe VideoConversion::BaseAdapter do
  before(:each) do
    extensions = SiteSetting.authorized_extensions.split("|")
    SiteSetting.authorized_extensions = (extensions | ["mp4"]).join("|")
  end

  fab!(:user)
  fab!(:chat_message) { Fabricate(:chat_message, user: user) }
  let!(:upload) { Fabricate(:video_upload, user: user) }

  before do
    SiteSetting.video_conversion_service = "aws_mediaconvert"
    SiteSetting.mediaconvert_role_arn = "arn:aws:iam::123456789012:role/MediaConvertRole"
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_use_iam_profile = true
    SiteSetting.video_conversion_enabled = true

    # Link upload to chat message
    UploadReference.create!(target: chat_message, upload: upload)
  end

  describe "when video conversion completes" do
    let(:optimized_upload) { Fabricate(:upload, user: user, extension: "mp4") }
    let(:optimized_video) do
      OptimizedVideo.create!(
        upload: upload,
        optimized_upload: optimized_upload,
        adapter: "aws_mediaconvert",
      )
    end

    it "rebakes chat messages that use the upload" do
      # Reload to get fresh instance for expectation
      message = Chat::Message.find(chat_message.id)
      allow(message).to receive(:rebake!)

      # Stub the query to return our message
      relation = instance_double(ActiveRecord::Relation)
      allow(Chat::Message).to receive(:where).with(id: [chat_message.id]).and_return(relation)
      allow(relation).to receive(:includes).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(message)

      adapter = described_class.new(upload)
      adapter.send(:update_posts_with_optimized_video, optimized_video)

      expect(message).to have_received(:rebake!)
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
