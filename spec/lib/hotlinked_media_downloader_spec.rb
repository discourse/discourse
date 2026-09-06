# frozen_string_literal: true

RSpec.describe HotlinkedMediaDownloader do
  fab!(:user)

  let(:image_url) { "http://example.com/image.png" }
  let(:png) { Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7") }

  before do
    SiteSetting.max_image_size_kb = 2
    stub_request(:get, image_url).to_return(body: png, headers: { "Content-Type" => "image/png" })
  end

  it "downloads and creates an upload" do
    stub_image_size
    upload = described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    expect(upload).to be_persisted
    expect(upload.user_id).to eq(user.id)
  end

  it "raises ImageBrokenError when the download fails" do
    stub_request(:get, image_url).to_return(status: 404)
    expect {
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    }.to raise_error(described_class::ImageBrokenError)
  end

  it "raises ImageTooLargeError when the file exceeds the limit" do
    huge = "a" * (SiteSetting.max_image_size_kb * 1024 * 2)
    stub_request(:get, image_url).to_return(body: huge, headers: { "Content-Type" => "image/png" })
    expect {
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    }.to raise_error(described_class::ImageTooLargeError)
  end
end
