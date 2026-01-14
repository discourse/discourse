# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::UploadEncoder do
  let(:gif) { plugin_file_from_fixtures("1x1.gif") }
  let(:jpg) { plugin_file_from_fixtures("1x1.jpg") }
  let(:webp) { plugin_file_from_fixtures("1x1.webp") }

  before { enable_current_plugin }

  it "automatically converts gifs to pngs" do
    upload = UploadCreator.new(gif, "1x1.gif").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "automatically converts webp to pngs" do
    upload = UploadCreator.new(webp, "1x1.webp").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "supports jpg" do
    upload = UploadCreator.new(jpg, "1x1.jpg").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/jpeg")
  end
end
