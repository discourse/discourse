# frozen_string_literal: true

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

  context 'avatar_sizes' do
    it 'returns a list of integers' do
      expect(Discourse.avatar_sizes).to contain_exactly(20, 25, 30, 32, 37, 40, 45, 48, 50, 60, 64, 67, 75, 90, 96, 120, 135, 180, 240, 360)
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

  context "asset_filter_options" do
    it "obmits path if request is missing" do
      opts = Discourse.asset_filter_options(:js, nil)
      expect(opts[:path]).to be_blank
    end

    it "returns a hash with a path from the request" do
      req = stub(fullpath: "/hello", headers: {})
      opts = Discourse.asset_filter_options(:js, req)
      expect(opts[:path]).to eq("/hello")
    end
  end

  context 'plugins' do
    let(:plugin_class) do
      Class.new(Plugin::Instance) do
        attr_accessor :enabled
        def enabled?
          @enabled
        end
      end
    end

    let(:plugin1) { plugin_class.new.tap { |p| p.enabled = true; p.path = "my-plugin-1" } }
    let(:plugin2) { plugin_class.new.tap { |p| p.enabled = false; p.path = "my-plugin-1" } }

    before do
      Discourse.plugins.append(plugin1, plugin2)
    end

    after do
      Discourse.plugins.delete plugin1
      Discourse.plugins.delete plugin2
      DiscoursePluginRegistry.reset!
    end

    before do
      plugin_class.any_instance.stubs(:css_asset_exists?).returns(true)
      plugin_class.any_instance.stubs(:js_asset_exists?).returns(true)
    end

    it 'can find plugins correctly' do
      expect(Discourse.plugins).to include(plugin1, plugin2)

      # Exclude disabled plugins by default
      expect(Discourse.find_plugins({})).to include(plugin1)

      # Include disabled plugins when requested
      expect(Discourse.find_plugins(include_disabled: true)).to include(plugin1, plugin2)
    end

    it 'can find plugin assets' do
      plugin2.enabled = true

      expect(Discourse.find_plugin_css_assets({}).length).to eq(2)
      expect(Discourse.find_plugin_js_assets({}).length).to eq(2)
      plugin1.register_asset_filter do |type, request, opts|
        false
      end
      expect(Discourse.find_plugin_css_assets({}).length).to eq(1)
      expect(Discourse.find_plugin_js_assets({}).length).to eq(1)
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

    fab!(:admin) { Fabricate(:admin) }
    fab!(:another_admin) { Fabricate(:admin) }

    it 'returns the user specified by the site setting site_contact_username' do
      SiteSetting.site_contact_username = another_admin.username
      expect(Discourse.site_contact_user).to eq(another_admin)
    end

    it 'returns the system user otherwise' do
      SiteSetting.site_contact_username = nil
      expect(Discourse.site_contact_user.username).to eq("system")
    end

  end

  context '#system_user' do
    it 'returns the system user' do
      expect(Discourse.system_user.id).to eq(-1)
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
      Discourse.redis.del(readonly_mode_key)
      Discourse.redis.del(user_readonly_mode_key)
    end

    def assert_readonly_mode(message, key, ttl = -1)
      expect(message.channel).to eq(Discourse.readonly_channel)
      expect(message.data).to eq(true)
      expect(Discourse.redis.get(key)).to eq("1")
      expect(Discourse.redis.ttl(key)).to eq(ttl)
    end

    def assert_readonly_mode_disabled(message, key)
      expect(message.channel).to eq(Discourse.readonly_channel)
      expect(message.data).to eq(false)
      expect(Discourse.redis.get(key)).to eq(nil)
    end

    describe ".enable_readonly_mode" do
      it "adds a key in redis and publish a message through the message bus" do
        expect(Discourse.redis.get(readonly_mode_key)).to eq(nil)
      end

      context 'user enabled readonly mode' do
        it "adds a key in redis and publish a message through the message bus" do
          expect(Discourse.redis.get(user_readonly_mode_key)).to eq(nil)
        end
      end
    end

    describe ".disable_readonly_mode" do
      context 'user disabled readonly mode' do
        it "removes readonly key in redis and publish a message through the message bus" do
          message = MessageBus.track_publish { Discourse.disable_readonly_mode(user_readonly_mode_key) }.first
          assert_readonly_mode_disabled(message, user_readonly_mode_key)
        end
      end
    end

    describe ".readonly_mode?" do
      it "is false by default" do
        expect(Discourse.readonly_mode?).to eq(false)
      end

      it "returns true when the key is present in redis" do
        Discourse.redis.set(readonly_mode_key, 1)
        expect(Discourse.readonly_mode?).to eq(true)
      end

      it "returns true when postgres is recently read only" do
        Discourse.received_postgres_readonly!
        expect(Discourse.readonly_mode?).to eq(true)
      end

      it "returns true when redis is recently read only" do
        Discourse.received_redis_readonly!
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

    describe ".received_postgres_readonly!" do
      it "sets the right time" do
        time = Discourse.received_postgres_readonly!
        expect(Discourse.postgres_last_read_only['default']).to eq(time)
      end
    end

    describe ".received_redis_readonly!" do
      it "sets the right time" do
        time = Discourse.received_redis_readonly!
        expect(Discourse.redis_last_read_only['default']).to eq(time)
      end
    end

    describe ".clear_readonly!" do
      it "publishes the right message" do
        Discourse.received_postgres_readonly!
        messages = []

        expect do
          messages = MessageBus.track_publish { Discourse.clear_readonly! }
        end.to change { Discourse.postgres_last_read_only['default'] }.to(nil)

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

      expect do
        Discourse.handle_job_exception(exception, nil, nil)
      end.to raise_error(StandardError) # Raises in test mode, catch it

      expect(logger.exception).to eq(exception)
      expect(logger.context.keys).to eq([:current_db, :current_hostname])
    end

    it "correctly passes extra context" do
      exception = StandardError.new

      expect do
        Discourse.handle_job_exception(exception, { message: "Doing a test", post_id: 31 }, nil)
      end.to raise_error(StandardError) # Raises in test mode, catch it

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

  describe "Utils.execute_command" do
    it "works for individual commands" do
      expect(Discourse::Utils.execute_command("pwd").strip).to eq(Rails.root.to_s)
      expect(Discourse::Utils.execute_command("pwd", chdir: "plugins").strip).to eq("#{Rails.root.to_s}/plugins")
    end

    it "supports timeouts" do
      expect do
        Discourse::Utils.execute_command("sleep", "999999999999", timeout: 0.001)
      end.to raise_error(RuntimeError)

      expect do
        Discourse::Utils.execute_command({ "MYENV" => "MYVAL" }, "sleep", "999999999999", timeout: 0.001)
      end.to raise_error(RuntimeError)
    end

    it "works with a block" do
      Discourse::Utils.execute_command do |runner|
        expect(runner.exec("pwd").strip).to eq(Rails.root.to_s)
      end

      result = Discourse::Utils.execute_command(chdir: "plugins") do |runner|
        expect(runner.exec("pwd").strip).to eq("#{Rails.root.to_s}/plugins")
        runner.exec("pwd")
      end

      # Should return output of block
      expect(result.strip).to eq("#{Rails.root.to_s}/plugins")
    end

    it "does not leak chdir between threads" do
      has_done_chdir = false
      has_checked_chdir = false

      thread = Thread.new do
        Discourse::Utils.execute_command(chdir: "plugins") do
          has_done_chdir = true
          sleep(0.01) until has_checked_chdir
        end
      end

      sleep(0.01) until has_done_chdir
      expect(Discourse::Utils.execute_command("pwd").strip).to eq(Rails.root.to_s)
      has_checked_chdir = true
      thread.join
    end

    it "raises error for unsafe shell" do
      expect(Discourse::Utils.execute_command("pwd").strip).to eq(Rails.root.to_s)

      expect do
        Discourse::Utils.execute_command("echo a b c")
      end.to raise_error(RuntimeError)

      expect do
        Discourse::Utils.execute_command({ "ENV1" => "VAL" }, "echo a b c")
      end.to raise_error(RuntimeError)

      expect(Discourse::Utils.execute_command("echo", "a", "b", "c").strip).to eq("a b c")
      expect(Discourse::Utils.execute_command("echo a b c", unsafe_shell: true).strip).to eq("a b c")
    end
  end

end
