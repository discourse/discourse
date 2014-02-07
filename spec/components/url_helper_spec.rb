require 'spec_helper'
require_dependency 'url_helper'

describe UrlHelper do

  class DummyClass
    include UrlHelper
  end

  let(:helper) { DummyClass.new }

  describe "#is_local" do

    it "is true when the file has been uploaded" do
      store = stub
      store.expects(:has_been_uploaded?).returns(true)
      Discourse.stubs(:store).returns(store)
      helper.is_local("http://discuss.site.com/path/to/file.png").should be_true
    end

    it "is true for relative assets" do
      store = stub
      store.expects(:has_been_uploaded?).returns(false)
      Discourse.stubs(:store).returns(store)
      helper.is_local("/assets/javascripts/all.js").should be_true
    end

    it "is true for plugin assets" do
      store = stub
      store.expects(:has_been_uploaded?).returns(false)
      Discourse.stubs(:store).returns(store)
      helper.is_local("/plugins/all.js").should be_true
    end

  end

  describe "#absolute" do

    it "does not change non-relative url" do
      helper.absolute("http://www.discourse.org").should == "http://www.discourse.org"
    end

    it "changes a relative url to an absolute one using base url by default" do
      helper.absolute("/path/to/file").should == "http://test.localhost/path/to/file"
    end

    it "changes a relative url to an absolute one using the cdn when enabled" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      helper.absolute("/path/to/file").should == "http://my.cdn.com/path/to/file"
    end

  end

  describe "#absolute_without_cdn" do

    it "changes a relative url to an absolute one using base url even when cdn is enabled" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      helper.absolute_without_cdn("/path/to/file").should == "http://test.localhost/path/to/file"
    end

  end

  describe "#schemaless" do

    it "removes http or https schemas only" do
      helper.schemaless("http://www.discourse.org").should == "//www.discourse.org"
      helper.schemaless("https://secure.discourse.org").should == "//secure.discourse.org"
      helper.schemaless("ftp://ftp.discourse.org").should == "ftp://ftp.discourse.org"
    end

  end

end
