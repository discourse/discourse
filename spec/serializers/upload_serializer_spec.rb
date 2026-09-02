# frozen_string_literal: true

RSpec.describe UploadSerializer do
  subject(:serializer) { UploadSerializer.new(upload, root: false) }

  fab!(:upload)

  it "should render without errors" do
    json_data = JSON.parse(serializer.to_json)

    expect(json_data["id"]).to eql upload.id
    expect(json_data["width"]).to eql upload.width
    expect(json_data["height"]).to eql upload.height
    expect(json_data["thumbnail_width"]).to eql upload.thumbnail_width
    expect(json_data["thumbnail_height"]).to eql upload.thumbnail_height
    expect(json_data["short_path"]).to eql upload.short_path
    expect(json_data).not_to include(
      "audio_duration_ms",
      "audio_waveform",
      "audio_waveform_version",
    )
  end

  it "includes stored audio metadata" do
    waveform = Array.new(Upload::AUDIO_WAVEFORM_SAMPLES) { |index| index }
    upload.update!(
      audio_duration_ms: 2_000,
      audio_waveform: waveform.pack("C*"),
      audio_waveform_version: Upload::AUDIO_WAVEFORM_VERSION,
    )

    json_data = JSON.parse(serializer.to_json)

    expect(json_data["audio_duration_ms"]).to eq(2_000)
    expect(json_data["audio_waveform"]).to eq(waveform)
    expect(json_data["audio_waveform_version"]).to eq(Upload::AUDIO_WAVEFORM_VERSION)
  end

  context "when the upload is secure" do
    fab!(:upload, :secure_upload)

    context "when secure uploads is disabled" do
      it "just returns the normal URL, otherwise S3 errors are encountered" do
        UrlHelper.expects(:cook_url).with(upload.url, secure: false)
        serializer.to_json
      end
    end

    context "when secure uploads is enabled" do
      before do
        setup_s3
        SiteSetting.secure_uploads = true
      end

      it "returns the cooked URL based on the upload URL" do
        UrlHelper.expects(:cook_url).with(upload.url, secure: true)
        serializer.to_json
      end
    end
  end
end
