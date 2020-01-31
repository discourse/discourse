# frozen_string_literal: true

require 'rails_helper'

describe UrlHelper do

  describe "#relaxed parse" do

    it "can handle double #" do
      url = UrlHelper.relaxed_parse("https://test.com#test#test")
      expect(url.to_s).to eq("https://test.com#test%23test")
    end

  end

  describe "#is_local" do

    it "is true when the file has been uploaded" do
      store = stub
      store.expects(:has_been_uploaded?).returns(true)
      Discourse.stubs(:store).returns(store)
      expect(UrlHelper.is_local("http://discuss.site.com/path/to/file.png")).to eq(true)
    end

    it "is true for relative assets" do
      store = stub
      store.expects(:has_been_uploaded?).returns(false)
      Discourse.stubs(:store).returns(store)
      expect(UrlHelper.is_local("/assets/javascripts/all.js")).to eq(true)
    end

    it "is true for relative assets for subfolders" do
      store = stub
      store.expects(:has_been_uploaded?).returns(false)
      Discourse.stubs(:store).returns(store)

      set_subfolder "/subpath"
      expect(UrlHelper.is_local("/subpath/assets/javascripts/all.js")).to eq(true)
    end

    it "is true for plugin assets" do
      store = stub
      store.expects(:has_been_uploaded?).returns(false)
      Discourse.stubs(:store).returns(store)
      expect(UrlHelper.is_local("/plugins/all.js")).to eq(true)
    end

  end

  describe "#absolute" do

    it "returns an absolute URL for CDN" do
      begin
        Rails.configuration.action_controller.asset_host = "//cdn.awesome.com"
        expect(UrlHelper.absolute("/test.jpg")).to eq("https://cdn.awesome.com/test.jpg")

        Rails.configuration.action_controller.asset_host = "https://cdn.awesome.com"
        expect(UrlHelper.absolute("/test.jpg")).to eq("https://cdn.awesome.com/test.jpg")

        Rails.configuration.action_controller.asset_host = "http://cdn.awesome.com"
        expect(UrlHelper.absolute("/test.jpg")).to eq("http://cdn.awesome.com/test.jpg")
      ensure
        Rails.configuration.action_controller.asset_host = nil
      end
    end

    it "does not change non-relative url" do
      expect(UrlHelper.absolute("http://www.discourse.org")).to eq("http://www.discourse.org")
    end

    it "changes a relative url to an absolute one using base url by default" do
      expect(UrlHelper.absolute("/path/to/file")).to eq("http://test.localhost/path/to/file")
    end

    it "changes a relative url to an absolute one using the cdn when enabled" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      expect(UrlHelper.absolute("/path/to/file")).to eq("http://my.cdn.com/path/to/file")
    end

  end

  describe "#absolute_without_cdn" do

    it "changes a relative url to an absolute one using base url even when cdn is enabled" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      expect(UrlHelper.absolute_without_cdn("/path/to/file")).to eq("http://test.localhost/path/to/file")
    end

  end

  describe "#schemaless" do

    it "removes http schemas only" do
      expect(UrlHelper.schemaless("http://www.discourse.org")).to eq("//www.discourse.org")
      expect(UrlHelper.schemaless("https://secure.discourse.org")).to eq("https://secure.discourse.org")
      expect(UrlHelper.schemaless("ftp://ftp.discourse.org")).to eq("ftp://ftp.discourse.org")
    end

  end

  describe "#escape_uri" do
    it "doesn't escape simple URL" do
      url = UrlHelper.escape_uri('http://example.com/foo/bar')
      expect(url).to eq('http://example.com/foo/bar')
    end

    it "escapes unsafe chars" do
      url = UrlHelper.escape_uri("http://example.com/?a=\11\15")
      expect(url).to eq('http://example.com/?a=%09%0D')
    end

    it "escapes non-ascii chars" do
      url = UrlHelper.escape_uri('http://example.com/ماهی')
      expect(url).to eq('http://example.com/%D9%85%D8%A7%D9%87%DB%8C')
    end

    it "doesn't escape already escaped chars" do
      url = UrlHelper.escape_uri('http://example.com/foo%20bar/foo bar/')
      expect(url).to eq('http://example.com/foo%20bar/foo%20bar/')
    end

    it "doesn't escape S3 presigned URLs" do
      # both of these were originally real presigned URLs and have had all
      # sensitive information stripped
      presigned_url = "https://test.com/original/3X/b/5/575bcc2886bf7a39684b57ca90be85f7d399bbc7.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK8888999977%2F20200130%2Fus-west-1%2Fs3%2Faws4_request&X-Amz-Date=20200130T064355Z&X-Amz-Expires=15&X-Amz-SignedHeaders=host&X-Amz-Security-Token=blahblah%2Bblahblah%2Fblah%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQAR&X-Amz-Signature=test"
      encoded_presigned_url = "https://test.com/original/3X/b/5/575bcc2886bf7a39684b57ca90be85f7d399bbc7.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK8888999977/20200130/us-west-1/s3/aws4_request&X-Amz-Date=20200130T064355Z&X-Amz-Expires=15&X-Amz-SignedHeaders=host&X-Amz-Security-Token=blahblah+blahblah/blah//////////wEQA==&X-Amz-Signature=test"
      expect(UrlHelper.escape_uri(presigned_url)).not_to eq(encoded_presigned_url)
    end
  end

  describe "#local_cdn_url" do
    let(:url) { "/#{Discourse.store.upload_path}/1X/575bcc2886bf7a39684b57ca90be85f7d399bbc7.png" }
    let(:asset_host) { "//my.awesome.cdn" }

    it "should return correct cdn url for local relative urls" do
      set_cdn_url asset_host
      cdn_url = UrlHelper.local_cdn_url(url)
      expect(cdn_url).to eq("#{asset_host}#{url}")
    end
  end

  describe "#cook_url" do
    let(:url) { "//s3bucket.s3.dualstack.us-east-1.amazonaws.com/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg" }

    before do
      FileStore::S3Store.any_instance.stubs(:has_been_uploaded?).returns(true)
      Rails.configuration.action_controller.asset_host = "https://test.some-cdn.com/dev"
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3bucket"
      SiteSetting.s3_access_key_id = "s3_access_key_id"
      SiteSetting.s3_secret_access_key = "s3_secret_access_key"
      SiteSetting.login_required = true
    end

    def cooked
      UrlHelper.cook_url(url, secure: secure)
    end

    context "when the upload for the url is secure" do
      let(:secure) { true }

      it "returns the secure_proxy_without_cdn url, with no asset host URL change" do
        expect(cooked).to eq(
          "//test.localhost/secure-media-uploads/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg"
        )
      end
    end

    context "when the upload for the url is not secure" do
      let(:secure) { false }

      it "returns the local_cdn_url" do
        expect(cooked).to eq(
          "//s3bucket.s3.dualstack.us-east-1.amazonaws.com/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg"
        )
      end
    end

    after do
      Rails.configuration.action_controller.asset_host = nil
    end
  end

end
