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

  it "downloads only the authorized identity's bytes when a secure URL names another upload" do
    setup_s3
    stub_s3_store
    SiteSetting.secure_uploads = true
    source_post = Fabricate(:post, user: user)
    target_post = Fabricate(:post, user: user)
    private_post =
      Fabricate(
        :post,
        topic: Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group))),
      )
    allowed = Fabricate(:secure_upload_s3, access_control_post: source_post)
    forbidden = Fabricate(:secure_upload_s3, access_control_post: private_post)
    allowed_path = URI.parse(allowed.url).path
    forbidden_path = URI.parse(forbidden.url).path
    allowed_request =
      stub_request(:get, %r{\Ahttps://})
        .with { |request| request.uri.path == allowed_path }
        .to_return(body: png, headers: { "Content-Type" => "image/png" })
    forbidden_request =
      stub_request(:get, %r{\Ahttps://})
        .with { |request| request.uri.path == forbidden_path }
        .to_return(body: file_from_fixtures("smallest.png"))
    url = Upload.secure_uploads_url_from_upload_url(forbidden.url, base62_sha1: allowed.base62_sha1)
    expect(user.guardian.can_see_upload?(forbidden)).to eq(false)
    expect(Jobs::PullHotlinkedImages.new.should_download_image?(url, target_post)).to eq(true)

    upload = described_class.download(url, user.id, tmp_file_name: "test-hotlinked")

    expect(upload.original_sha1).to eq(Digest::SHA1.hexdigest(png))
    expect(allowed_request).to have_been_requested
    expect(forbidden_request).not_to have_been_requested
  end

  it "raises ImageBrokenError when the download fails" do
    stub_request(:get, image_url).to_return(status: 404)
    expect {
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    }.to raise_error(described_class::ImageBrokenError)
  end

  it "treats missing secure upload identities and foreign thumbnails as broken images" do
    setup_s3
    SiteSetting.secure_uploads = true
    upload = Fabricate(:secure_upload_s3)
    image = Fabricate(:optimized_image)
    image.update!(url: "#{SiteSetting.Upload.absolute_base_url}/#{image.url}")
    urls = [
      Upload.secure_uploads_url_from_upload_url(
        upload.url,
        base62_sha1: Upload.base62_sha1("f" * 40),
      ),
      Upload.secure_uploads_url_from_upload_url(image.url, base62_sha1: upload.base62_sha1),
    ]

    urls.each do |url|
      expect {
        described_class.download(url, user.id, tmp_file_name: "test-hotlinked")
      }.to raise_error(described_class::ImageBrokenError)
    end
  end

  it "raises RateLimitedError honouring Retry-After when the host rate limits" do
    stub_request(:get, image_url).to_return(status: 429, headers: { "Retry-After" => "120" })

    expect do
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    rescue => error
      expect(error.retry_after).to eq(120)
      raise
    end.to raise_error(described_class::RateLimitedError)
  end

  it "raises RateLimitedError with the minimum delay when there is no Retry-After" do
    stub_request(:get, image_url).to_return(status: 429)

    expect do
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    rescue => error
      expect(error.retry_after).to eq(described_class::MIN_RETRY_AFTER_SECONDS)
      raise
    end.to raise_error(described_class::RateLimitedError)
  end

  it "raises ImageTooLargeError when the file exceeds the limit" do
    huge = "a" * (SiteSetting.max_image_size_kb * 1024 * 2)
    stub_request(:get, image_url).to_return(body: huge, headers: { "Content-Type" => "image/png" })
    expect {
      described_class.download(image_url, user.id, tmp_file_name: "test-hotlinked")
    }.to raise_error(described_class::ImageTooLargeError)
  end
end
