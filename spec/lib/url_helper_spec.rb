# frozen_string_literal: true

RSpec.describe UrlHelper do
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
      expect(UrlHelper.absolute_without_cdn("/path/to/file")).to eq(
        "http://test.localhost/path/to/file",
      )
    end
  end

  describe "#schemaless" do
    it "removes http schemas only" do
      expect(UrlHelper.schemaless("http://www.discourse.org")).to eq("//www.discourse.org")
      expect(UrlHelper.schemaless("https://secure.discourse.org")).to eq(
        "https://secure.discourse.org",
      )
      expect(UrlHelper.schemaless("ftp://ftp.discourse.org")).to eq("ftp://ftp.discourse.org")
    end
  end

  describe "#normalized_encode" do
    it "does not double escape %3A (:)" do
      url = "http://discourse.org/%3A/test"
      expect(UrlHelper.normalized_encode(url)).to eq(url)
    end

    it "does not double escape %2F (/)" do
      url = "http://discourse.org/%2F/test"
      expect(UrlHelper.normalized_encode(url)).to eq(url)
    end

    it "doesn't escape simple URL" do
      url = UrlHelper.normalized_encode("http://example.com/foo/bar")
      expect(url).to eq("http://example.com/foo/bar")
    end

    it "escapes unsafe chars" do
      url = UrlHelper.normalized_encode("http://example.com/?a=\11\15")
      expect(url).to eq("http://example.com/?a=%09%0D")
    end

    it "escapes non-ascii chars" do
      url = UrlHelper.normalized_encode("http://example.com/ماهی")
      expect(url).to eq("http://example.com/%D9%85%D8%A7%D9%87%DB%8C")
    end

    it "doesn't escape already escaped chars (space)" do
      url = UrlHelper.normalized_encode("http://example.com/foo%20bar/foo bar/")
      expect(url).to eq("http://example.com/foo%20bar/foo%20bar/")
    end

    it "doesn't escape already escaped chars (hash)" do
      url =
        "https://calendar.google.com/calendar/embed?src=en.uk%23holiday@group.v.calendar.google.com&ctz=Europe%2FLondon"
      escaped = UrlHelper.normalized_encode(url)
      expect(escaped).to eq(url)
    end

    it "leaves reserved chars alone in edge cases" do
      skip "see: https://github.com/sporkmonger/addressable/issues/472"
      url = "https://example.com/ article/id%3A1.2%2F1/bar"
      expected = "https://example.com/%20article/id%3A1.2%2F1/bar"
      escaped = UrlHelper.normalized_encode(url)
      expect(escaped).to eq(expected)
    end

    it "handles emoji domain names" do
      url = "https://💻.example/💻?computer=💻"
      expected = "https://xn--3s8h.example/%F0%9F%92%BB?computer=%F0%9F%92%BB"
      escaped = UrlHelper.normalized_encode(url)
      expect(escaped).to eq(expected)
    end

    it "handles special-character domain names" do
      url = "https://éxample.com/test"
      expected = "https://xn--xample-9ua.com/test"
      escaped = UrlHelper.normalized_encode(url)
      expect(escaped).to eq(expected)
    end

    it "performs basic normalization" do
      url = "http://EXAMPLE.com/a"
      escaped = UrlHelper.normalized_encode(url)
      expect(escaped).to eq("http://example.com/a")
    end

    it "doesn't escape S3 presigned URLs" do
      # both of these were originally real presigned URLs and have had all
      # sensitive information stripped
      presigned_url =
        "https://test.com/original/3X/b/5/575bcc2886bf7a39684b57ca90be85f7d399bbc7.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK8888999977%2F20200130%2Fus-west-1%2Fs3%2Faws4_request&X-Amz-Date=20200130T064355Z&X-Amz-Expires=15&X-Amz-SignedHeaders=host&X-Amz-Security-Token=blahblah%2Bblahblah%2Fblah%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQAR&X-Amz-Signature=test"
      encoded_presigned_url =
        "https://test.com/original/3X/b/5/575bcc2886bf7a39684b57ca90be85f7d399bbc7.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK8888999977/20200130/us-west-1/s3/aws4_request&X-Amz-Date=20200130T064355Z&X-Amz-Expires=15&X-Amz-SignedHeaders=host&X-Amz-Security-Token=blahblah+blahblah/blah//////////wEQA==&X-Amz-Signature=test"
      expect(UrlHelper.normalized_encode(presigned_url)).not_to eq(encoded_presigned_url)
    end

    it "raises error if too long" do
      long_url = "https://#{"a" * 2_000}.com"
      expect do UrlHelper.normalized_encode(long_url) end.to raise_error(
        ArgumentError,
        "URL starting with #{long_url[0..100]} is too long",
      )
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

  describe "#rails_route_from_url" do
    it "recognizes a user path" do
      result = UrlHelper.rails_route_from_url("http://example.com/u/john_smith")
      expect(result[:controller]).to eq("users")
      expect(result[:action]).to eq("show")
      expect(result[:username]).to eq("john_smith")
    end

    it "recognizes a user path with unicode characters in the username" do
      result = UrlHelper.rails_route_from_url("http://example.com/u/björn_ulvaeus")
      expect(result[:controller]).to eq("users")
      expect(result[:action]).to eq("show")
      expect(result[:username].force_encoding("UTF-8")).to eq("björn_ulvaeus")
    end
  end

  describe "#cook_url" do
    let(:url) do
      "//s3bucket.s3.dualstack.us-west-1.amazonaws.com/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg"
    end

    before do
      setup_s3
      SiteSetting.s3_upload_bucket = "s3bucket"
      SiteSetting.login_required = true
      Rails.configuration.action_controller.asset_host = "https://test.some-cdn.com/dev"

      FileStore::S3Store.any_instance.stubs(:has_been_uploaded?).returns(true)

      SiteSetting.secure_uploads = true
    end

    def cooked
      UrlHelper.cook_url(url, secure: secure)
    end

    context "when the upload for the url is secure" do
      let(:secure) { true }

      it "returns the secure_proxy_without_cdn url, with no asset host URL change" do
        expect(cooked).to eq(
          "//test.localhost/secure-uploads/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg",
        )
      end

      context "when secure_uploads setting is disabled" do
        before { SiteSetting.secure_uploads = false }

        it "returns the local_cdn_url" do
          expect(cooked).to eq(
            "//s3bucket.s3.dualstack.us-west-1.amazonaws.com/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg",
          )
        end
      end
    end

    context "when the upload for the url is not secure" do
      let(:secure) { false }

      it "returns the local_cdn_url" do
        expect(cooked).to eq(
          "//s3bucket.s3.dualstack.us-west-1.amazonaws.com/dev/original/3X/2/e/2e6f2ef81b6910ea592cd6d21ee897cd51cf72e4.jpeg",
        )
      end
    end

    after { Rails.configuration.action_controller.asset_host = nil }
  end

  describe "rails_route_from_url" do
    it "returns a rails route from the path" do
      expect(described_class.rails_route_from_url("/u")).to eq(
        { controller: "users", action: "index" },
      )
    end

    it "does not raise for invalid URLs" do
      url = "http://URL:%20https://google.com"
      expect(described_class.rails_route_from_url(url)).to eq(nil)
    end

    it "does not raise for invalid mailtos" do
      url = "mailto:eviltrout%2540example.com"
      expect(described_class.rails_route_from_url(url)).to eq(nil)
    end
  end

  describe ".is_valid_url?" do
    it "should return true for a valid HTTP URL" do
      expect(described_class.is_valid_url?("http://www.example.com")).to eq(true)
    end

    it "should return true for a valid HTTPS URL" do
      expect(described_class.is_valid_url?("https://www.example.com")).to eq(true)
    end

    it "should return true for a valid FTP URL" do
      expect(described_class.is_valid_url?("ftp://example.com")).to eq(true)
    end

    it "should return true for a valid mailto URL" do
      expect(described_class.is_valid_url?("mailto:someone@discourse.org")).to eq(true)
    end

    it "should return true for a valid LDAP URL" do
      expect(described_class.is_valid_url?("ldap://ldap.example.com/dc=example;dc=com?quer")).to eq(
        true,
      )
    end

    it "should return true for a path" do
      expect(described_class.is_valid_url?("/some/path")).to eq(true)
    end

    it "should return true for a path with query params" do
      expect(described_class.is_valid_url?("/some/path?query=param")).to eq(true)
    end

    it "should return true for anchor links" do
      expect(described_class.is_valid_url?("#anchor")).to eq(true)
      expect(described_class.is_valid_url?("#")).to eq(true)
    end

    it "should return false for invalid urls" do
      expect(described_class.is_valid_url?("")).to eq(false)
      expect(described_class.is_valid_url?("http//www.example.com")).to eq(false)
      expect(described_class.is_valid_url?("http:/www.example.com")).to eq(false)
      expect(described_class.is_valid_url?("https:///www.example.com")).to eq(false)
      expect(described_class.is_valid_url?("mailtoooo:someone@discourse.org")).to eq(false)
      expect(described_class.is_valid_url?("ftp://")).to eq(false)
      expect(described_class.is_valid_url?("http://")).to eq(false)
      expect(described_class.is_valid_url?("https://")).to eq(false)
      expect(described_class.is_valid_url?("ldap://")).to eq(false)
    end
  end
end
