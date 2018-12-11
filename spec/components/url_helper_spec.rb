require 'rails_helper'
require_dependency 'url_helper'

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
  end

end
