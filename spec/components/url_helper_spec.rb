require 'rails_helper'
require_dependency 'url_helper'

describe UrlHelper do

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

end
