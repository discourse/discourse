# frozen_string_literal: true

RSpec.describe "Secure upload hotlinks" do
  fab!(:attacker) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:member) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:private_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: private_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic) }

  let(:signed_upload_url) { "https://s3.example.com/signed-private-upload.png" }
  let(:base_uri) { URI.parse(Discourse.base_url) }
  let(:mismatched_scheme) { base_uri.scheme == "https" ? "http" : "https" }

  let(:private_upload) do
    Fabricate(:secure_upload_s3, secure: true).tap do |upload|
      upload.update!(access_control_post: private_post, width: 0, height: 0)
    end
  end

  let(:secure_path) { Upload.secure_uploads_url_from_upload_url(private_upload.url) }

  before do
    enable_secure_uploads
    Jobs.run_immediately!
    SiteSetting.download_remote_images_to_local = true
    SiteSetting.download_remote_images_threshold = 0

    stub_upload(private_upload)
    FileStore::S3Store.any_instance.stubs(:signed_url_for_path).returns(signed_upload_url)
    FileStore::S3Store.any_instance.stubs(:store_upload).returns(private_upload.url)
    stub_request(:get, signed_upload_url).to_return(
      status: 200,
      body: file_from_fixtures("smallest.png"),
    )
    stub_request(
      :get,
      /\Ahttps?:#{Regexp.escape(private_upload.url.sub(/\Ahttps?:/, ""))}/,
    ).to_return(status: 200, body: file_from_fixtures("smallest.png"))
    stub_request(:get, /attacker\.invalid/).to_return(status: 404)
    stub_request(:get, %r{/#{Regexp.escape(base_uri.host)}(:\d+)?/secure-uploads/}).to_return(
      status: 404,
    )
  end

  it "does not sign or copy a private upload for a foreign absolute secure URL" do
    expect_hotlink_not_signed("https://attacker.invalid#{secure_path}")
  end

  it "does not sign or copy a private upload for a foreign scheme-relative secure URL" do
    expect_hotlink_not_signed("//attacker.invalid#{secure_path}")
  end

  it "does not sign or copy a private upload for a same-host URL with a mismatched scheme" do
    expect_hotlink_not_signed(
      "#{mismatched_scheme}://#{base_uri.host}:#{base_uri.port}#{secure_path}",
    )
  end

  it "does not sign or copy a private upload for a same-origin URL carrying userinfo" do
    expect_hotlink_not_signed(
      "#{base_uri.scheme}://ignored@#{base_uri.host}:#{base_uri.port}#{secure_path}",
    )
  end

  it "does not copy a first-party scheme-relative secure URL the author cannot see" do
    upload_count = Upload.count
    sign_in(attacker)

    post "/posts.json",
         params: {
           title: "A public post with a hotlinked image",
           raw: "<img src='//#{base_uri.host}:#{base_uri.port}#{secure_path}'>",
         }

    aggregate_failures do
      expect(response.status).to eq(200)
      expect(attacker.guardian.can_see_post?(private_post)).to eq(false)
      expect(Upload.count).to eq(upload_count)
      expect(Post.find(response.parsed_body["id"]).post_hotlinked_media).to be_empty
    end
  end

  it "does not copy an absolute secure URL outside the site's subfolder that the author cannot see" do
    upload_count = Upload.count
    url = "#{base_uri.scheme}://#{base_uri.host}:#{base_uri.port}#{secure_path}"
    set_subfolder "/forum"
    sign_in(attacker)

    post "/posts.json",
         params: {
           title: "A public post with a hotlinked image",
           raw: "<img src='#{url}'>",
         }

    aggregate_failures do
      expect(response.status).to eq(200)
      expect(attacker.guardian.can_see_post?(private_post)).to eq(false)
      expect(Upload.count).to eq(upload_count)
      expect(Post.find(response.parsed_body["id"]).post_hotlinked_media).to be_empty
    end
  end

  it "does not copy a private upload when the URL also names an upload the author can see" do
    visible_upload =
      Fabricate(:secure_upload_s3, secure: true).tap do |upload|
        upload.update!(access_control_post: Fabricate(:post), width: 0, height: 0)
      end
    visible_key =
      Upload.secure_uploads_url_from_upload_url(visible_upload.url).delete_prefix("/secure-uploads")
    urls = [
      "#{secure_path.sub("/original/", "/original//")}?x=#{visible_key}",
      "#{secure_path.sub("/original/", "/original%2F")}?x=#{visible_key}",
      "#{secure_path.sub("/original/", "/original//")}##{visible_key}",
    ]
    upload_count = Upload.count
    sign_in(attacker)

    post "/posts.json",
         params: {
           title: "A public post with a hotlinked image",
           raw: urls.map { |url| "<img src='#{url}'>" }.join("\n"),
         }

    aggregate_failures do
      expect(response.status).to eq(200)
      expect(attacker.guardian.can_see_post?(private_post)).to eq(false)
      expect(Upload.count).to eq(upload_count)
      expect(Post.find(response.parsed_body["id"]).post_hotlinked_media).to be_empty
    end
  end

  it "still signs a first-party secure upload when the author can see the owning post" do
    private_group.add(member)
    sign_in(member)
    local_url = "#{base_uri.scheme}://#{base_uri.host}:#{base_uri.port}#{secure_path}"

    expect do
      post "/posts.json",
           params: {
             title: "A public post with a hotlinked image",
             raw: "<img src='#{local_url}'>",
           }
    end.to change { Upload.count }.by(1)

    expect(response.status).to eq(200)
    expect(a_request(:get, signed_upload_url)).to have_been_made.at_least_once
  end

  context "when the site origin uses a custom port" do
    before { SiteSetting.port = 8443 }

    it "still signs a first-party scheme-relative secure URL carrying the custom port" do
      private_group.add(member)
      sign_in(member)

      expect do
        post "/posts.json",
             params: {
               title: "A public post with a hotlinked image",
               raw: "<img src='//#{base_uri.host}:8443#{secure_path}'>",
             }
      end.to change { Upload.count }.by(1)

      expect(response.status).to eq(200)
      expect(a_request(:get, signed_upload_url)).to have_been_made.at_least_once
    end

    it "does not sign a secure URL that omits the custom port" do
      expect_hotlink_not_signed("//#{base_uri.host}#{secure_path}")
    end
  end

  def expect_hotlink_not_signed(url)
    upload_count = Upload.count
    sign_in(attacker)

    post "/posts.json",
         params: {
           title: "A public post with a hotlinked image",
           raw: "<img src='#{url}'>",
         }

    aggregate_failures do
      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to be_present
      expect(attacker.guardian.can_see_post?(private_post)).to eq(false)
      expect(Upload.count).to eq(upload_count)
      expect(a_request(:get, signed_upload_url)).not_to have_been_made
    end
  end
end
