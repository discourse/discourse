# frozen_string_literal: true

require "discourse"

RSpec.describe Discourse do
  before { RailsMultisite::ConnectionManagement.stubs(:current_hostname).returns("foo.com") }

  describe "current_hostname" do
    it "returns the hostname from the current db connection" do
      expect(Discourse.current_hostname).to eq("foo.com")
    end
  end

  describe "avatar_sizes" do
    it "returns a list of integers" do
      SiteSetting.avatar_sizes = "10|20|30"
      expect(Discourse.avatar_sizes).to contain_exactly(10, 20, 30)
    end
  end

  describe "running_in_rack" do
    after { ENV.delete("DISCOURSE_RUNNING_IN_RACK") }

    it "should not be running in rack" do
      expect(Discourse.running_in_rack?).to eq(false)
      ENV["DISCOURSE_RUNNING_IN_RACK"] = "1"
      expect(Discourse.running_in_rack?).to eq(true)
    end
  end

  describe "base_url" do
    context "when https is off" do
      before { SiteSetting.force_https = false }

      it "has a non https base url" do
        expect(Discourse.base_url).to eq("http://foo.com")
      end
    end

    context "when https is on" do
      before { SiteSetting.force_https = true }

      it "has a non-ssl base url" do
        expect(Discourse.base_url).to eq("https://foo.com")
      end
    end

    context "with a non standard port specified" do
      before { SiteSetting.port = 3000 }

      it "returns the non standard port in the base url" do
        expect(Discourse.base_url).to eq("http://foo.com:3000")
      end
    end
  end

  describe "asset_filter_options" do
    it "omits path if request is missing" do
      opts = Discourse.asset_filter_options(:js, nil)
      expect(opts[:path]).to be_blank
    end

    it "returns a hash with a path from the request" do
      req = stub(fullpath: "/hello", headers: {})
      opts = Discourse.asset_filter_options(:js, req)
      expect(opts[:path]).to eq("/hello")
    end
  end

  describe ".plugins_sorted_by_name" do
    before do
      Discourse.stubs(:visible_plugins).returns(
        [
          stub(enabled?: false, name: "discourse-doctor-sleep", humanized_name: "Doctor Sleep"),
          stub(enabled?: true, name: "discourse-shining", humanized_name: "The Shining"),
          stub(enabled?: true, name: "discourse-misery", humanized_name: "misery"),
        ],
      )
    end

    it "sorts enabled plugins by humanized name" do
      expect(Discourse.plugins_sorted_by_name.map(&:name)).to eq(
        %w[discourse-misery discourse-shining],
      )
    end

    it "sorts both enabled and disabled plugins when that option is provided" do
      expect(Discourse.plugins_sorted_by_name(enabled_only: false).map(&:name)).to eq(
        %w[discourse-doctor-sleep discourse-misery discourse-shining],
      )
    end
  end

  describe "plugins" do
    let(:plugin_class) do
      Class.new(Plugin::Instance) do
        attr_accessor :enabled
        def enabled?
          @enabled
        end
      end
    end

    let(:plugin1) do
      plugin_class.new.tap do |p|
        p.enabled = true
        p.path = "my-plugin-1"
      end
    end
    let(:plugin2) do
      plugin_class.new.tap do |p|
        p.enabled = false
        p.path = "my-plugin-1"
      end
    end

    before { Discourse.plugins.append(plugin1, plugin2) }

    after do
      Discourse.plugins.delete plugin1
      Discourse.plugins.delete plugin2
      DiscoursePluginRegistry.reset!
    end

    before do
      plugin_class.any_instance.stubs(:css_asset_exists?).returns(true)
      plugin_class.any_instance.stubs(:js_asset_exists?).returns(true)
    end

    it "can find plugins correctly" do
      expect(Discourse.plugins).to include(plugin1, plugin2)

      # Exclude disabled plugins by default
      expect(Discourse.find_plugins({})).to include(plugin1)

      # Include disabled plugins when requested
      expect(Discourse.find_plugins(include_disabled: true)).to include(plugin1, plugin2)
    end

    it "can find plugin assets" do
      plugin2.enabled = true

      expect(Discourse.find_plugin_css_assets({}).length).to eq(2)
      expect(Discourse.find_plugin_js_assets({}).length).to eq(2)
      plugin1.register_asset_filter { |type, request, opts| false }
      expect(Discourse.find_plugin_css_assets({}).length).to eq(1)
      expect(Discourse.find_plugin_js_assets({}).length).to eq(1)
    end
  end

  describe "authenticators" do
    it "returns inbuilt authenticators" do
      expect(Discourse.authenticators).to match_array(Discourse::BUILTIN_AUTH.map(&:authenticator))
    end

    context "with authentication plugin installed" do
      let(:plugin_auth_provider) do
        authenticator_class =
          Class.new(Auth::Authenticator) do
            def name
              "pluginauth"
            end

            def enabled?
              true
            end
          end

        provider = Auth::AuthProvider.new
        provider.authenticator = authenticator_class.new
        provider
      end

      before { DiscoursePluginRegistry.register_auth_provider(plugin_auth_provider) }

      after { DiscoursePluginRegistry.reset! }

      it "returns inbuilt and plugin authenticators" do
        expect(Discourse.authenticators).to match_array(
          Discourse::BUILTIN_AUTH.map(&:authenticator) + [plugin_auth_provider.authenticator],
        )
      end
    end
  end

  describe "enabled_authenticators" do
    it "only returns enabled authenticators" do
      expect(Discourse.enabled_authenticators.length).to be(0)
      expect { SiteSetting.enable_twitter_logins = true }.to change {
        Discourse.enabled_authenticators.length
      }.by(1)
      expect(Discourse.enabled_authenticators.length).to be(1)
      expect(Discourse.enabled_authenticators.first).to be_instance_of(Auth::TwitterAuthenticator)
    end
  end

  describe "#site_contact_user" do
    fab!(:admin)
    fab!(:another_admin) { Fabricate(:admin) }

    it "returns the user specified by the site setting site_contact_username" do
      SiteSetting.site_contact_username = another_admin.username
      expect(Discourse.site_contact_user).to eq(another_admin)
    end

    it "returns the system user otherwise" do
      SiteSetting.site_contact_username = nil
      expect(Discourse.site_contact_user.username).to eq("system")
    end
  end

  describe "#system_user" do
    it "returns the system user" do
      expect(Discourse.system_user.id).to eq(-1)
    end
  end

  describe "#store" do
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

  describe "readonly mode" do
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
      it "doesn't expire when expires is false" do
        Discourse.enable_readonly_mode(user_readonly_mode_key, expires: false)
        expect(Discourse.redis.ttl(user_readonly_mode_key)).to eq(-1)
      end

      it "expires when expires is true" do
        Discourse.enable_readonly_mode(user_readonly_mode_key, expires: true)
        expect(Discourse.redis.ttl(user_readonly_mode_key)).not_to eq(-1)
      end

      it "adds a key in redis and publish a message through the message bus" do
        expect(Discourse.redis.get(readonly_mode_key)).to eq(nil)
      end

      context "when user enabled readonly mode" do
        it "adds a key in redis and publish a message through the message bus" do
          expect(Discourse.redis.get(user_readonly_mode_key)).to eq(nil)
        end
      end
    end

    describe ".disable_readonly_mode" do
      context "when user disabled readonly mode" do
        it "removes readonly key in redis and publish a message through the message bus" do
          message =
            MessageBus
              .track_publish { Discourse.disable_readonly_mode(user_readonly_mode_key) }
              .first
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

      it "returns true when forced via global setting" do
        expect(Discourse.readonly_mode?).to eq(false)
        global_setting :pg_force_readonly_mode, true
        expect(Discourse.readonly_mode?).to eq(true)
      end
    end

    describe ".received_postgres_readonly!" do
      it "sets the right time" do
        time = Discourse.received_postgres_readonly!
        expect(Discourse.redis.get(Discourse::LAST_POSTGRES_READONLY_KEY).to_i).to eq(time.to_i)
      end
    end

    describe ".received_redis_readonly!" do
      it "sets the right time" do
        time = Discourse.received_redis_readonly!
        expect(Discourse.redis_last_read_only["default"]).to eq(time)
      end
    end

    describe ".clear_readonly!" do
      it "publishes the right message" do
        Discourse.received_postgres_readonly!
        messages = []

        expect do messages = MessageBus.track_publish { Discourse.clear_readonly! } end.to change {
          Discourse.redis.get(Discourse::LAST_POSTGRES_READONLY_KEY)
        }.to(nil)

        expect(messages.any? { |m| m.channel == Site::SITE_JSON_CHANNEL }).to eq(true)
      end
    end
  end

  describe "#handle_exception" do
    class TempSidekiqLogger
      attr_accessor :exception, :context

      def call(ex, ctx)
        self.exception = ex
        self.context = ctx
      end
    end

    let!(:logger) { TempSidekiqLogger.new }

    before { Sidekiq.error_handlers << logger }

    after { Sidekiq.error_handlers.delete(logger) }

    describe "#job_exception_stats" do
      class FakeTestError < StandardError
      end

      before { Discourse.reset_job_exception_stats! }

      after { Discourse.reset_job_exception_stats! }

      it "should not fail on incorrectly shaped hash" do
        expect do
          Discourse.handle_job_exception(FakeTestError.new, { job: "test" })
        end.to raise_error(FakeTestError)
      end

      it "should collect job exception stats" do
        # see MiniScheduler Manager which reports it like this
        # https://github.com/discourse/mini_scheduler/blob/2b2c1c56b6e76f51108c2a305775469e24cf2b65/lib/mini_scheduler/manager.rb#L95
        exception_context = {
          message: "Running a scheduled job",
          job: {
            "class" => Jobs::ReindexSearch,
          },
        }

        # re-raised unconditionally in test env
        2.times do
          expect {
            Discourse.handle_job_exception(FakeTestError.new, exception_context)
          }.to raise_error(FakeTestError)
        end

        exception_context = {
          message: "Running a scheduled job",
          job: {
            "class" => Jobs::PollMailbox,
          },
        }

        expect {
          Discourse.handle_job_exception(FakeTestError.new, exception_context)
        }.to raise_error(FakeTestError)

        expect(Discourse.job_exception_stats).to eq(
          { Jobs::PollMailbox => 1, Jobs::ReindexSearch => 2 },
        )
      end
    end

    it "should not fail when called" do
      exception = StandardError.new

      expect do Discourse.handle_job_exception(exception, nil, nil) end.to raise_error(
        StandardError,
      ) # Raises in test mode, catch it

      expect(logger.exception).to eq(exception)
      expect(logger.context.keys).to eq(%i[current_db current_hostname])
    end

    it "correctly passes extra context" do
      exception = StandardError.new

      expect do
        Discourse.handle_job_exception(exception, { message: "Doing a test", post_id: 31 }, nil)
      end.to raise_error(StandardError) # Raises in test mode, catch it

      expect(logger.exception).to eq(exception)
      expect(logger.context.keys.sort).to eq(%i[current_db current_hostname message post_id].sort)
    end
  end

  describe "#deprecate" do
    def old_method(m)
      Discourse.deprecate(m)
    end

    def old_method_caller(m)
      old_method(m)
    end

    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "can deprecate usage" do
      k = SecureRandom.hex
      expect(old_method_caller(k)).to include("old_method_caller")
      expect(old_method_caller(k)).to include("discourse_spec")
      expect(old_method_caller(k)).to include(k)

      expect(fake_logger.warnings).to eq([old_method_caller(k)])
    end

    it "can report the deprecated version" do
      Discourse.deprecate(SecureRandom.hex, since: "2.1.0.beta1")

      expect(fake_logger.warnings[0]).to include("(deprecated since Discourse 2.1.0.beta1)")
    end

    it "can report the drop version" do
      Discourse.deprecate(SecureRandom.hex, drop_from: "2.3.0")

      expect(fake_logger.warnings[0]).to include("(removal in Discourse 2.3.0)")
    end

    it "can raise deprecation error" do
      expect { Discourse.deprecate(SecureRandom.hex, raise_error: true) }.to raise_error(
        Discourse::Deprecation,
      )
    end
  end

  describe "Utils.execute_command" do
    it "works for individual commands" do
      expect(Discourse::Utils.execute_command("pwd").strip).to eq(Rails.root.to_s)
      expect(Discourse::Utils.execute_command("pwd", chdir: "plugins").strip).to eq(
        "#{Rails.root}/plugins",
      )
    end

    it "supports timeouts" do
      expect do
        Discourse::Utils.execute_command("sleep", "999999999999", timeout: 0.001)
      end.to raise_error(RuntimeError)

      expect do
        Discourse::Utils.execute_command(
          { "MYENV" => "MYVAL" },
          "sleep",
          "999999999999",
          timeout: 0.001,
        )
      end.to raise_error(RuntimeError)
    end

    it "works with a block" do
      Discourse::Utils.execute_command do |runner|
        expect(runner.exec("pwd").strip).to eq(Rails.root.to_s)
      end

      result =
        Discourse::Utils.execute_command(chdir: "plugins") do |runner|
          expect(runner.exec("pwd").strip).to eq("#{Rails.root}/plugins")
          runner.exec("pwd")
        end

      # Should return output of block
      expect(result.strip).to eq("#{Rails.root}/plugins")
    end

    it "does not leak chdir between threads" do
      has_done_chdir = false
      has_checked_chdir = false

      thread =
        Thread.new do
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

      expect do Discourse::Utils.execute_command("echo a b c") end.to raise_error(RuntimeError)

      expect do
        Discourse::Utils.execute_command({ "ENV1" => "VAL" }, "echo a b c")
      end.to raise_error(RuntimeError)

      expect(Discourse::Utils.execute_command("echo", "a", "b", "c").strip).to eq("a b c")
      expect(Discourse::Utils.execute_command("echo a b c", unsafe_shell: true).strip).to eq(
        "a b c",
      )
    end
  end

  describe ".clear_all_theme_cache!" do
    before do
      setup_s3
      SiteSetting.s3_cdn_url = "https://s3.cdn.com/gg"
      stub_s3_store
    end

    let!(:theme) { Fabricate(:theme) }
    let!(:upload) { Fabricate(:s3_image_upload) }
    let!(:upload_theme_field) do
      Fabricate(
        :theme_field,
        theme: theme,
        upload: upload,
        type_id: ThemeField.types[:theme_upload_var],
        target_id: Theme.targets[:common],
        name: "imajee",
        value: "",
      )
    end
    let!(:basic_html_field) do
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:html],
        target_id: Theme.targets[:common],
        name: "head_tag",
        value: <<~HTML,
          <script type="text/discourse-plugin" version="0.1">
            console.log(settings.uploads.imajee);
          </script>
        HTML
      )
    end
    let!(:js_field) do
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:js],
        target_id: Theme.targets[:extra_js],
        name: "somefile.js",
        value: <<~JS,
          console.log(settings.uploads.imajee);
        JS
      )
    end
    let!(:scss_field) do
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:scss],
        target_id: Theme.targets[:common],
        name: "scss",
        value: <<~SCSS,
          .something { background: url($imajee); }
        SCSS
      )
    end

    it "invalidates all JS and CSS caches" do
      Stylesheet::Manager.clear_theme_cache!

      old_upload_url = Discourse.store.cdn_url(upload.url)

      head_tag_script =
        Nokogiri::HTML5
          .fragment(Theme.lookup_field(theme.id, :desktop, "head_tag"))
          .css("script")
          .first
      head_tag_js = JavascriptCache.find_by(digest: head_tag_script[:src][/\h{40}/]).content
      expect(head_tag_js).to include(old_upload_url)

      js_file_script =
        Nokogiri::HTML5.fragment(Theme.lookup_field(theme.id, :extra_js, nil)).css("script").first
      file_js = JavascriptCache.find_by(digest: js_file_script[:src][/\h{40}/]).content
      expect(file_js).to include(old_upload_url)

      css_link_tag =
        Nokogiri::HTML5
          .fragment(
            Stylesheet::Manager.new(theme_id: theme.id).stylesheet_link_tag(:desktop_theme, "all"),
          )
          .css("link")
          .first
      css = StylesheetCache.find_by(digest: css_link_tag[:href][/\h{40}/]).content
      expect(css).to include("url(#{old_upload_url})")

      SiteSetting.s3_cdn_url = "https://new.s3.cdn.com/gg"
      new_upload_url = Discourse.store.cdn_url(upload.url)

      head_tag_script =
        Nokogiri::HTML5
          .fragment(Theme.lookup_field(theme.id, :desktop, "head_tag"))
          .css("script")
          .first
      head_tag_js = JavascriptCache.find_by(digest: head_tag_script[:src][/\h{40}/]).content
      expect(head_tag_js).to include(old_upload_url)

      js_file_script =
        Nokogiri::HTML5.fragment(Theme.lookup_field(theme.id, :extra_js, nil)).css("script").first
      file_js = JavascriptCache.find_by(digest: js_file_script[:src][/\h{40}/]).content
      expect(file_js).to include(old_upload_url)

      css_link_tag =
        Nokogiri::HTML5
          .fragment(
            Stylesheet::Manager.new(theme_id: theme.id).stylesheet_link_tag(:desktop_theme, "all"),
          )
          .css("link")
          .first
      css = StylesheetCache.find_by(digest: css_link_tag[:href][/\h{40}/]).content
      expect(css).to include("url(#{old_upload_url})")

      Discourse.clear_all_theme_cache!

      head_tag_script =
        Nokogiri::HTML5
          .fragment(Theme.lookup_field(theme.id, :desktop, "head_tag"))
          .css("script")
          .first
      head_tag_js = JavascriptCache.find_by(digest: head_tag_script[:src][/\h{40}/]).content
      expect(head_tag_js).to include(new_upload_url)

      js_file_script =
        Nokogiri::HTML5.fragment(Theme.lookup_field(theme.id, :extra_js, nil)).css("script").first
      file_js = JavascriptCache.find_by(digest: js_file_script[:src][/\h{40}/]).content
      expect(file_js).to include(new_upload_url)

      css_link_tag =
        Nokogiri::HTML5
          .fragment(
            Stylesheet::Manager.new(theme_id: theme.id).stylesheet_link_tag(:desktop_theme, "all"),
          )
          .css("link")
          .first
      css = StylesheetCache.find_by(digest: css_link_tag[:href][/\h{40}/]).content
      expect(css).to include("url(#{new_upload_url})")
    end
  end
end
