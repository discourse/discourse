require 'spec_helper'
require 'discourse'

describe Discourse do

  before do
    RailsMultisite::ConnectionManagement.stubs(:current_hostname).returns('foo.com')
  end

  context 'current_hostname' do

    it 'returns the hostname from the current db connection' do
      expect(Discourse.current_hostname).to eq('foo.com')
    end

  end

  context 'base_url' do
    context 'when https is off' do
      before do
        SiteSetting.expects(:use_https?).returns(false)
      end

      it 'has a non https base url' do
        expect(Discourse.base_url).to eq("http://foo.com")
      end
    end

    context 'when https is on' do
      before do
        SiteSetting.expects(:use_https?).returns(true)
      end

      it 'has a non-ssl base url' do
        expect(Discourse.base_url).to eq("https://foo.com")
      end
    end

    context 'with a non standard port specified' do
      before do
        SiteSetting.stubs(:port).returns(3000)
      end

      it "returns the non standart port in the base url" do
        expect(Discourse.base_url).to eq("http://foo.com:3000")
      end
    end
  end

  context '#site_contact_user' do

    let!(:admin) { Fabricate(:admin) }
    let!(:another_admin) { Fabricate(:admin) }

    it 'returns the user specified by the site setting site_contact_username' do
      SiteSetting.stubs(:site_contact_username).returns(another_admin.username)
      expect(Discourse.site_contact_user).to eq(another_admin)
    end

    it 'returns the user specified by the site setting site_contact_username regardless of its case' do
      SiteSetting.stubs(:site_contact_username).returns(another_admin.username.upcase)
      expect(Discourse.site_contact_user).to eq(another_admin)
    end

    it 'returns the first admin user otherwise' do
      SiteSetting.stubs(:site_contact_username).returns(nil)
      expect(Discourse.site_contact_user).to eq(admin)
    end

  end

  context "#store" do

    it "returns LocalStore by default" do
      expect(Discourse.store).to be_a(FileStore::LocalStore)
    end

    it "returns S3Store when S3 is enabled" do
      SiteSetting.stubs(:enable_s3_uploads?).returns(true)
      SiteSetting.stubs(:s3_upload_bucket).returns("s3_bucket")
      SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
      SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
      expect(Discourse.store).to be_a(FileStore::S3Store)
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
    it "is false by default" do
      expect(Discourse.readonly_mode?).to eq(false)
    end

    it "returns true when the key is present in redis" do
      $redis.expects(:get).with(Discourse.readonly_mode_key).returns("1")
      expect(Discourse.readonly_mode?).to eq(true)
    end

    it "returns true when Discourse is recently read only" do
      Discourse.received_readonly!
      expect(Discourse.readonly_mode?).to eq(true)
    end
  end

  context "#handle_exception" do

    class TempSidekiqLogger < Sidekiq::ExceptionHandler::Logger
      attr_accessor :exception, :context
      def call(ex, ctx)
        self.exception = ex
        self.context = ctx
      end
    end

    let!(:logger) { TempSidekiqLogger.new }

    before do
      Sidekiq.error_handlers.clear
      Sidekiq.error_handlers << logger
    end

    it "should not fail when called" do
      exception = StandardError.new

      Discourse.handle_job_exception(exception, nil, nil)
      expect(logger.exception).to eq(exception)
      expect(logger.context.keys).to eq([:current_db, :current_hostname])
    end

    it "correctly passes extra context" do
      exception = StandardError.new

      Discourse.handle_job_exception(exception, {message: "Doing a test", post_id: 31}, nil)
      expect(logger.exception).to eq(exception)
      expect(logger.context.keys.sort).to eq([:current_db, :current_hostname, :message, :post_id].sort)
    end
  end

end

