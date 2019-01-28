require 'rails_helper'
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

  context 'running_in_rack' do
    after do
      ENV.delete("DISCOURSE_RUNNING_IN_RACK")
    end

    it 'should not be running in rack' do
      expect(Discourse.running_in_rack?).to eq(false)
      ENV["DISCOURSE_RUNNING_IN_RACK"] = "1"
      expect(Discourse.running_in_rack?).to eq(true)
    end
  end

  context 'base_url' do
    context 'when https is off' do
      before do
        SiteSetting.force_https = false
      end

      it 'has a non https base url' do
        expect(Discourse.base_url).to eq("http://foo.com")
      end
    end

    context 'when https is on' do
      before do
        SiteSetting.force_https = true
      end

      it 'has a non-ssl base url' do
        expect(Discourse.base_url).to eq("https://foo.com")
      end
    end

    context 'with a non standard port specified' do
      before do
        SiteSetting.port = 3000
      end

      it "returns the non standart port in the base url" do
        expect(Discourse.base_url).to eq("http://foo.com:3000")
      end
    end
  end

  context 'authenticators' do
    it 'returns inbuilt authenticators' do
      expect(Discourse.authenticators).to match_array(Discourse::BUILTIN_AUTH.map(&:authenticator))
    end

    context 'with authentication plugin installed' do
      let(:plugin_auth_provider) do
        authenticator_class = Class.new(Auth::Authenticator) do
          def name
            'pluginauth'
          end

          def enabled
            true
          end
        end

        provider = Auth::AuthProvider.new
        provider.authenticator = authenticator_class.new
        provider
      end

      before do
        DiscoursePluginRegistry.register_auth_provider(plugin_auth_provider)
      end

      after do
        DiscoursePluginRegistry.reset!
      end

      it 'returns inbuilt and plugin authenticators' do
        expect(Discourse.authenticators).to match_array(
          Discourse::BUILTIN_AUTH.map(&:authenticator) + [plugin_auth_provider.authenticator])
      end

    end
  end

  context 'enabled_authenticators' do
    it 'only returns enabled authenticators' do
      expect(Discourse.enabled_authenticators.length).to be(0)
      expect { SiteSetting.enable_twitter_logins = true }
        .to change { Discourse.enabled_authenticators.length }.by(1)
      expect(Discourse.enabled_authenticators.length).to be(1)
      expect(Discourse.enabled_authenticators.first).to be_instance_of(Auth::TwitterAuthenticator)
    end
  end

  context '#site_contact_user' do

    let!(:admin) { Fabricate(:admin) }
    let!(:another_admin) { Fabricate(:admin) }

    it 'returns the user specified by the site setting site_contact_username' do
      SiteSetting.site_contact_username = another_admin.username
      expect(Discourse.site_contact_user).to eq(another_admin)
    end

    it 'returns the system user otherwise' do
      SiteSetting.site_contact_username = nil
      expect(Discourse.site_contact_user.username).to eq("system")
    end

  end

  context "#store" do

    it "returns LocalStore by default" do
      expect(Discourse.store).to be_a(FileStore::LocalStore)
    end

    it "returns S3Store when S3 is enabled" do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3bucket"
      SiteSetting.s3_access_key_id = "s3_access_key_id"
      SiteSetting.s3_secret_access_key = "s3_secret_access_key"
      expect(Discourse.store).to be_a(FileStore::S3Store)
    end

  end

  context 'readonly mode' do
    let(:readonly_mode_key) { Discourse::READONLY_MODE_KEY }
    let(:readonly_mode_ttl) { Discourse::READONLY_MODE_KEY_TTL }
    let(:user_readonly_mode_key) { Discourse::USER_READONLY_MODE_KEY }

    after do
      $redis.del(readonly_mode_key)
      $redis.del(user_readonly_mode_key)
    end

    def assert_readonly_mode(message, key, ttl = -1)
      expect(message.channel).to eq(Discourse.readonly_channel)
      expect(message.data).to eq(true)
      expect($redis.get(key)).to eq("1")
      expect($redis.ttl(key)).to eq(ttl)
    end

    def assert_readonly_mode_disabled(message, key)
      expect(message.channel).to eq(Discourse.readonly_channel)
      expect(message.data).to eq(false)
      expect($redis.get(key)).to eq(nil)
    end

    def get_readonly_message
      message = nil

      messages = MessageBus.track_publish do
        yield
      end

      expect(messages.any? { |m| m.channel == Site::SITE_JSON_CHANNEL })
        .to eq(true)

      messages.find { |m| m.channel == Discourse.readonly_channel }
    end

    describe ".enable_readonly_mode" do
      it "adds a key in redis and publish a message through the message bus" do
        expect($redis.get(readonly_mode_key)).to eq(nil)
        message = get_readonly_message { Discourse.enable_readonly_mode }
        assert_readonly_mode(message, readonly_mode_key, readonly_mode_ttl)
      end

      context 'user enabled readonly mode' do
        it "adds a key in redis and publish a message through the message bus" do
          expect($redis.get(user_readonly_mode_key)).to eq(nil)
          message = get_readonly_message { Discourse.enable_readonly_mode(user_readonly_mode_key) }
          assert_readonly_mode(message, user_readonly_mode_key)
        end
      end
    end

    describe ".disable_readonly_mode" do
      it "removes a key from redis and publish a message through the message bus" do
        message = get_readonly_message { Discourse.disable_readonly_mode }
        assert_readonly_mode_disabled(message, readonly_mode_key)
      end

      context 'user disabled readonly mode' do
        it "removes readonly key in redis and publish a message through the message bus" do
          Discourse.enable_readonly_mode(user_enabled: true)
          message = get_readonly_message { Discourse.disable_readonly_mode(user_enabled: true) }
          assert_readonly_mode_disabled(message, user_readonly_mode_key)
        end
      end
    end

    describe ".readonly_mode?" do
      it "is false by default" do
        expect(Discourse.readonly_mode?).to eq(false)
      end

      it "returns true when the key is present in redis" do
        $redis.set(readonly_mode_key, 1)
        expect(Discourse.readonly_mode?).to eq(true)
      end

      it "returns true when Discourse is recently read only" do
        Discourse.received_readonly!
        expect(Discourse.readonly_mode?).to eq(true)
      end

      it "returns true when user enabled readonly mode key is present in redis" do
        Discourse.enable_readonly_mode(user_readonly_mode_key)
        expect(Discourse.readonly_mode?).to eq(true)
        expect(Discourse.readonly_mode?(readonly_mode_key)).to eq(false)

        Discourse.disable_readonly_mode(user_readonly_mode_key)
        expect(Discourse.readonly_mode?).to eq(false)
      end
    end

    describe ".received_readonly!" do
      it "sets the right time" do
        time = Discourse.received_readonly!
        expect(Discourse.last_read_only['default']).to eq(time)
      end
    end

    describe ".clear_readonly!" do
      it "publishes the right message" do
        Discourse.received_readonly!
        messages = []

        expect do
          messages = MessageBus.track_publish { Discourse.clear_readonly! }
        end.to change { Discourse.last_read_only['default'] }.to(nil)

        expect(messages.any? { |m| m.channel == Site::SITE_JSON_CHANNEL })
          .to eq(true)
      end
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

      Discourse.handle_job_exception(exception, { message: "Doing a test", post_id: 31 }, nil)
      expect(logger.exception).to eq(exception)
      expect(logger.context.keys.sort).to eq([:current_db, :current_hostname, :message, :post_id].sort)
    end
  end

  context '#deprecate' do
    def old_method(m)
      Discourse.deprecate(m)
    end

    def old_method_caller(m)
      old_method(m)
    end

    before do
      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after do
      Rails.logger = @orig_logger
    end

    it 'can deprecate usage' do
      k = SecureRandom.hex
      expect(old_method_caller(k)).to include("old_method_caller")
      expect(old_method_caller(k)).to include("discourse_spec")
      expect(old_method_caller(k)).to include(k)

      expect(Rails.logger.warnings).to eq([old_method_caller(k)])
    end

    it 'can report the deprecated version' do
      Discourse.deprecate(SecureRandom.hex, since: "2.1.0.beta1")

      expect(Rails.logger.warnings[0]).to include("(deprecated since Discourse 2.1.0.beta1)")
    end

    it 'can report the drop version' do
      Discourse.deprecate(SecureRandom.hex, drop_from: "2.3.0")

      expect(Rails.logger.warnings[0]).to include("(removal in Discourse 2.3.0)")
    end

    it 'can raise deprecation error' do
      expect {
        Discourse.deprecate(SecureRandom.hex, raise_error: true)
      }.to raise_error(Discourse::Deprecation)
    end
  end

end
