require 'spec_helper'
require 'discourse'

describe Discourse do

  before do
    RailsMultisite::ConnectionManagement.stubs(:current_hostname).returns('foo.com')
  end

  context 'current_hostname' do

    it 'returns the hostname from the current db connection' do
      Discourse.current_hostname.should == 'foo.com'
    end

  end

  context 'base_url' do
    context 'when ssl is off' do
      before do
        SiteSetting.expects(:use_ssl?).returns(false)
      end

      it 'has a non-ssl base url' do
        Discourse.base_url.should == "http://foo.com"
      end
    end

    context 'when ssl is on' do
      before do
        SiteSetting.expects(:use_ssl?).returns(true)
      end

      it 'has a non-ssl base url' do
        Discourse.base_url.should == "https://foo.com"
      end
    end

    context 'with a non standard port specified' do
      before do
        SiteSetting.stubs(:port).returns(3000)
      end

      it "returns the non standart port in the base url" do
        Discourse.base_url.should == "http://foo.com:3000"
      end
    end
  end

  context '#site_contact_user' do

    let!(:admin) { Fabricate(:admin) }
    let!(:another_admin) { Fabricate(:admin) }

    it 'returns the user specified by the site setting site_contact_username' do
      SiteSetting.stubs(:site_contact_username).returns(another_admin.username)
      Discourse.site_contact_user.should == another_admin
    end

    it 'returns the first admin user otherwise' do
      SiteSetting.stubs(:site_contact_username).returns(nil)
      Discourse.site_contact_user.should == admin
    end

  end

  context "#store" do

    it "returns LocalStore by default" do
      Discourse.store.should be_a(LocalStore)
    end

    it "returns S3Store when S3 is enabled" do
      SiteSetting.expects(:enable_s3_uploads?).returns(true)
      Discourse.store.should be_a(S3Store)
    end

  end

end

