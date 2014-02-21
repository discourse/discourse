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
    context 'when https is off' do
      before do
        SiteSetting.expects(:use_https?).returns(false)
      end

      it 'has a non https base url' do
        Discourse.base_url.should == "http://foo.com"
      end
    end

    context 'when https is on' do
      before do
        SiteSetting.expects(:use_https?).returns(true)
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

    it 'returns the user specified by the site setting site_contact_username regardless of its case' do
      SiteSetting.stubs(:site_contact_username).returns(another_admin.username.upcase)
      Discourse.site_contact_user.should == another_admin
    end

    it 'returns the first admin user otherwise' do
      SiteSetting.stubs(:site_contact_username).returns(nil)
      Discourse.site_contact_user.should == admin
    end

  end

  context "#store" do

    it "returns LocalStore by default" do
      Discourse.store.should be_a(FileStore::LocalStore)
    end

    it "returns S3Store when S3 is enabled" do
      SiteSetting.expects(:enable_s3_uploads?).returns(true)
      Discourse.store.should be_a(FileStore::S3Store)
    end

  end

  context "#enable_readonly_mode" do

    it "adds a key in redis and publish a message through the message bus" do
      $redis.expects(:set).with(Discourse.readonly_mode_key, 1)
      MessageBus.expects(:publish).with(Discourse.readonly_channel, true)
      Discourse.enable_readonly_mode
    end

  end

  context "#disable_readonly_mode" do

    it "removes a key from redis and publish a message through the message bus" do
      $redis.expects(:del).with(Discourse.readonly_mode_key)
      MessageBus.expects(:publish).with(Discourse.readonly_channel, false)
      Discourse.disable_readonly_mode
    end

  end

  context "#readonly_mode?" do

    it "returns true when the key is present in redis" do
      $redis.expects(:get).with(Discourse.readonly_mode_key).returns("1")
      Discourse.readonly_mode?.should == true
    end

    it "returns false when the key is not present in redis" do
      $redis.expects(:get).with(Discourse.readonly_mode_key).returns(nil)
      Discourse.readonly_mode?.should == false
    end

  end

  context "#handle_exception" do
    class TempLogger
      attr_accessor :exception, :context
      def handle_exception(exception, context)
        self.exception = exception
        self.context = context
      end
    end
    
    it "should not fail when called" do
      logger = TempLogger.new
      exception = StandardError.new

      Discourse.handle_exception(exception, nil, logger)
      logger.exception.should == exception
      logger.context.keys.should == [:current_db, :current_hostname]
    end
  end

end

