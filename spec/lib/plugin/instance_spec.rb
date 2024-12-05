# frozen_string_literal: true

RSpec.describe Plugin::Instance do
  subject(:plugin_instance) { described_class.new(metadata) }

  let(:metadata) { Plugin::Metadata.parse <<TEXT }
# name: discourse-sample-plugin
# about: about: my plugin
# version: 0.1
# authors: Frank Zappa
# contact emails: frankz@example.com
# url: http://discourse.org
# required version: 1.3.0beta6+48
# meta_topic_id: 1234
# label: experimental

some_ruby
TEXT

  around { |example| allow_missing_translations(&example) }

  after { DiscoursePluginRegistry.reset! }

  # NOTE: sample_plugin_site_settings.yml is always loaded in tests in site_setting.rb

  describe ".humanized_name" do
    before do
      TranslationOverride.upsert!(
        "en",
        "admin_js.admin.site_settings.categories.discourse_sample_plugin",
        "Sample Plugin Category Name",
      )
    end

    it "defaults to using the plugin name with the discourse- prefix removed" do
      expect(plugin_instance.humanized_name).to eq("sample-plugin")
    end

    it "uses the plugin setting category name if it exists" do
      plugin_instance.enabled_site_setting(:discourse_sample_plugin_enabled)
      expect(plugin_instance.humanized_name).to eq("Sample Plugin Category Name")
    end

    it "the plugin name the plugin site settings are still under the generic plugins: category" do
      plugin_instance.stubs(:setting_category).returns("plugins")
      expect(plugin_instance.humanized_name).to eq("sample-plugin")
    end

    it "removes any Discourse prefix from the setting category name" do
      TranslationOverride.upsert!(
        "en",
        "admin_js.admin.site_settings.categories.discourse_sample_plugin",
        "Discourse Sample Plugin Category Name",
      )
      plugin_instance.enabled_site_setting(:discourse_sample_plugin_enabled)
      expect(plugin_instance.humanized_name).to eq("Sample Plugin Category Name")
    end
  end

  describe "find_all" do
    it "can find plugins correctly" do
      plugins = Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins")
      expect(plugins.count).to eq(5)
      plugin = plugins[3]

      expect(plugin.name).to eq("plugin-name")
      expect(plugin.path).to eq("#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb")

      plugin.git_repo.stubs(:latest_local_commit).returns("123456")
      plugin.git_repo.stubs(:url).returns("http://github.com/discourse/discourse-plugin")

      expect(plugin.commit_hash).to eq("123456")
      expect(plugin.commit_url).to eq("http://github.com/discourse/discourse-plugin/commit/123456")
      expect(plugin.discourse_owned?).to eq(true)
    end

    it "does not blow up on missing directory" do
      plugins = Plugin::Instance.find_all("#{Rails.root}/frank_zappa")
      expect(plugins.count).to eq(0)
    end
  end

  describe "stats" do
    after { DiscoursePluginRegistry.reset! }

    it "returns core stats" do
      stats = Plugin::Instance.stats
      expect(stats.keys).to contain_exactly(
        :topics_last_day,
        :topics_7_days,
        :topics_30_days,
        :topics_count,
        :posts_last_day,
        :posts_7_days,
        :posts_30_days,
        :posts_count,
        :users_last_day,
        :users_7_days,
        :users_30_days,
        :users_count,
        :active_users_last_day,
        :active_users_7_days,
        :active_users_30_days,
        :likes_last_day,
        :likes_7_days,
        :likes_30_days,
        :likes_count,
        :participating_users_last_day,
        :participating_users_7_days,
        :participating_users_30_days,
      )
    end

    it "returns stats registered by plugins" do
      plugin = Plugin::Instance.new
      stats_name = "plugin_stats"
      plugin.register_stat(stats_name) do
        { :last_day => 1, "7_days" => 10, "30_days" => 100, :count => 1000 }
      end

      stats = Plugin::Instance.stats

      expect(stats.with_indifferent_access).to match(
        hash_including(
          "#{stats_name}_last_day": 1,
          "#{stats_name}_7_days": 10,
          "#{stats_name}_30_days": 100,
          "#{stats_name}_count": 1000,
        ),
      )
    end
  end

  describe "git repo details" do
    describe ".discourse_owned?" do
      it "returns true if the plugin is on github in discourse-org or discourse orgs" do
        plugin = Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins")[3]
        plugin.git_repo.stubs(:latest_local_commit).returns("123456")
        plugin.git_repo.stubs(:url).returns("http://github.com/discourse/discourse-plugin")
        expect(plugin.discourse_owned?).to eq(true)

        plugin.git_repo.stubs(:url).returns("http://github.com/discourse-org/discourse-plugin")
        expect(plugin.discourse_owned?).to eq(true)

        plugin.git_repo.stubs(:url).returns("http://github.com/someguy/someguy-plugin")
        expect(plugin.discourse_owned?).to eq(false)
      end

      it "returns false if the commit_url is missing because of git command issues" do
        plugin = Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins")[3]
        plugin.git_repo.stubs(:latest_local_commit).returns(nil)
        expect(plugin.discourse_owned?).to eq(false)
      end
    end
  end

  describe "enabling/disabling" do
    it "is enabled by default" do
      expect(Plugin::Instance.new.enabled?).to eq(true)
    end

    context "with a plugin that extends things" do
      class Trout
        attr_accessor :data
      end

      class TroutSerializer < ApplicationSerializer
        attribute :name

        def name
          "a trout"
        end
      end

      class TroutJuniorSerializer < TroutSerializer
        attribute :i_am_child

        def name
          "a trout jr"
        end

        def i_am_child
          true
        end
      end

      class TroutPlugin < Plugin::Instance
        attr_accessor :enabled

        def enabled?
          @enabled
        end
      end

      before do
        @plugin = TroutPlugin.new
        @trout = Trout.new

        poison = TroutSerializer.new(@trout)
        poison.attributes

        poison = TroutJuniorSerializer.new(@trout)
        poison.attributes

        # New method
        @plugin.add_to_class(:trout, :status?) { "evil" }

        # DiscourseEvent
        @hello_count = 0
        @increase_count = -> { @hello_count += 1 }
        @set = @plugin.on(:hello, &@increase_count)

        # Serializer
        @plugin.add_to_serializer(:trout, :scales) { 1024 }
        @plugin.add_to_serializer(:trout, :unconditional_scales, respect_plugin_enabled: false) do
          2048
        end
        @plugin.add_to_serializer(
          :trout,
          :conditional_scales,
          include_condition: -> { !!object.data&.[](:has_scales) },
        ) { 4096 }

        @serializer = TroutSerializer.new(@trout)
        @child_serializer = TroutJuniorSerializer.new(@trout)
      end

      after { DiscourseEvent.off(:hello, &@set.first) }

      it "checks enabled/disabled functionality for extensions" do
        # with an enabled plugin
        @plugin.enabled = true
        expect(@trout.status?).to eq("evil")
        DiscourseEvent.trigger(:hello)
        expect(@hello_count).to eq(1)
        expect(@serializer.scales).to eq(1024)
        expect(@serializer.include_scales?).to eq(true)

        expect(@child_serializer.attributes[:scales]).to eq(1024)

        # When a plugin is disabled
        @plugin.enabled = false
        expect(@trout.status?).to eq(nil)
        DiscourseEvent.trigger(:hello)
        expect(@hello_count).to eq(1)
        expect(@serializer.scales).to eq(1024)
        expect(@serializer.include_scales?).to eq(false)
        expect(@serializer.include_unconditional_scales?).to eq(true)
        expect(@serializer.name).to eq("a trout")

        expect(@child_serializer.scales).to eq(1024)
        expect(@child_serializer.include_scales?).to eq(false)
        expect(@child_serializer.name).to eq("a trout jr")
      end

      it "can control the include_* implementation" do
        @plugin.enabled = true

        expect(@serializer.scales).to eq(1024)
        expect(@serializer.include_scales?).to eq(true)

        expect(@serializer.unconditional_scales).to eq(2048)
        expect(@serializer.include_unconditional_scales?).to eq(true)

        expect(@serializer.include_conditional_scales?).to eq(false)
        @trout.data = { has_scales: true }
        expect(@serializer.include_conditional_scales?).to eq(true)

        @plugin.enabled = false
        expect(@serializer.include_scales?).to eq(false)
        expect(@serializer.include_unconditional_scales?).to eq(true)
        expect(@serializer.include_conditional_scales?).to eq(false)
      end

      it "only returns HTML if enabled" do
        ctx = Trout.new
        ctx.data = "hello"

        @plugin.register_html_builder("test:html") { |c| "<div>#{c.data}</div>" }
        @plugin.enabled = false
        expect(DiscoursePluginRegistry.build_html("test:html", ctx)).to eq("")
        @plugin.enabled = true
        expect(DiscoursePluginRegistry.build_html("test:html", ctx)).to eq("<div>hello</div>")
      end

      it "can act when the plugin is enabled/disabled" do
        plugin = Plugin::Instance.new
        plugin.enabled_site_setting(:discourse_sample_plugin_enabled)

        SiteSetting.discourse_sample_plugin_enabled = false
        expect(plugin.enabled?).to eq(false)

        begin
          expected_old_value = expected_new_value = nil

          event_handler =
            plugin.on_enabled_change do |old_value, new_value|
              expected_old_value = old_value
              expected_new_value = new_value
            end

          SiteSetting.discourse_sample_plugin_enabled = true
          expect(expected_old_value).to eq(false)
          expect(expected_new_value).to eq(true)

          SiteSetting.discourse_sample_plugin_enabled = false
          expect(expected_old_value).to eq(true)
          expect(expected_new_value).to eq(false)

          # ensures only the setting specified in `enabled_site_setting` is tracked
          expected_old_value = expected_new_value = nil
          plugin.enabled_site_setting(:discourse_sample_plugin_enabled_alternative)
          SiteSetting.discourse_sample_plugin_enabled = true
          expect(expected_old_value).to be_nil
          expect(expected_new_value).to be_nil
        ensure
          # clear the underlying DiscourseEvent
          DiscourseEvent.off(:site_setting_changed, &event_handler)
        end
      end
    end
  end

  describe "register asset" do
    it "populates the DiscoursePluginRegistry" do
      plugin = Plugin::Instance.new nil, "/tmp/test.rb"
      plugin.register_asset("test.css")
      plugin.register_asset("test2.css")

      plugin.send :register_assets!

      expect(DiscoursePluginRegistry.mobile_stylesheets[plugin.directory_name]).to be_nil
      expect(DiscoursePluginRegistry.stylesheets[plugin.directory_name].count).to eq(2)
    end

    it "remaps vendored_core_pretty_text asset" do
      plugin = Plugin::Instance.new nil, "/tmp/test.rb"
      plugin.register_asset("moment.js", :vendored_core_pretty_text)

      plugin.send :register_assets!

      expect(DiscoursePluginRegistry.vendored_core_pretty_text.first).to eq(
        "vendor/assets/javascripts/moment.js",
      )
    end
  end

  describe "register service worker" do
    it "populates the DiscoursePluginRegistry" do
      plugin = Plugin::Instance.new nil, "/tmp/test.rb"
      plugin.register_service_worker("test.js")
      plugin.register_service_worker("test2.js")

      plugin.send :register_service_workers!

      expect(DiscoursePluginRegistry.service_workers.count).to eq(2)
    end
  end

  describe "#add_report" do
    after { Report.remove_report("readers") }

    it "adds a report" do
      plugin = Plugin::Instance.new nil, "/tmp/test.rb"
      plugin.add_report("readers") {}

      expect(Report.respond_to?(:report_readers)).to eq(true)
    end
  end

  describe "#activate!" do
    before do
      # lets piggy back on another boolean setting, so we don't dirty our SiteSetting object
      SiteSetting.enable_badges = false
    end

    it "can activate plugins correctly" do
      plugin = plugin_from_fixtures("my_plugin")
      junk_file = "#{plugin.auto_generated_path}/junk"

      plugin.ensure_directory(junk_file)
      File.open("#{plugin.auto_generated_path}/junk", "w") { |f| f.write("junk") }
      plugin.activate!

      # calls ensure_assets! make sure they are there
      expect(plugin.assets.count).to eq(1)
      plugin.assets.each { |a, opts| expect(File.exist?(a)).to eq(true) }

      # ensure it cleans up all crap in autogenerated directory
      expect(File.exist?(junk_file)).to eq(false)
    end

    it "registers auth providers correctly" do
      plugin = plugin_from_fixtures("my_plugin")
      plugin.activate!
      expect(DiscoursePluginRegistry.auth_providers.count).to eq(0)
      plugin.notify_after_initialize
      expect(DiscoursePluginRegistry.auth_providers.count).to eq(1)
      auth_provider = DiscoursePluginRegistry.auth_providers.to_a[0]
      expect(auth_provider.authenticator.name).to eq("facebook")
    end

    it "finds all the custom assets" do
      plugin = plugin_from_fixtures("my_plugin")

      plugin.register_asset("test.css")
      plugin.register_asset("test2.scss")
      plugin.register_asset("mobile.css", :mobile)
      plugin.register_asset("desktop.css", :desktop)
      plugin.register_asset("desktop2.css", :desktop)

      plugin.activate!

      expect(DiscoursePluginRegistry.javascripts.count).to eq(1)
      expect(DiscoursePluginRegistry.desktop_stylesheets[plugin.directory_name].count).to eq(2)
      expect(DiscoursePluginRegistry.stylesheets[plugin.directory_name].count).to eq(2)
      expect(DiscoursePluginRegistry.mobile_stylesheets[plugin.directory_name].count).to eq(1)
    end
  end

  describe "serialized_current_user_fields" do
    before { DiscoursePluginRegistry.serialized_current_user_fields << "has_car" }

    after { DiscoursePluginRegistry.serialized_current_user_fields.delete "has_car" }

    it "correctly serializes custom user fields" do
      DiscoursePluginRegistry.serialized_current_user_fields << "has_car"
      user = Fabricate(:user)
      user.custom_fields["has_car"] = "true"
      user.save!

      payload = JSON.parse(CurrentUserSerializer.new(user, scope: Guardian.new(user)).to_json)
      expect(payload["current_user"]["custom_fields"]["has_car"]).to eq("true")

      payload = JSON.parse(UserSerializer.new(user, scope: Guardian.new(user)).to_json)
      expect(payload["user"]["custom_fields"]["has_car"]).to eq("true")

      UserCustomField.destroy_all
      user.reload

      payload = JSON.parse(CurrentUserSerializer.new(user, scope: Guardian.new(user)).to_json)
      expect(payload["current_user"]["custom_fields"]).to eq({})

      payload = JSON.parse(UserSerializer.new(user, scope: Guardian.new(user)).to_json)
      expect(payload["user"]["custom_fields"]).to eq({})
    end
  end

  describe ".register_seedfu_fixtures" do
    it "should add the new path to SeedFu's fixtures path" do
      plugin = Plugin::Instance.new nil, "/tmp/test.rb"
      plugin.register_seedfu_fixtures(["some_path"])
      plugin.register_seedfu_fixtures("some_path2")

      expect(SeedFu.fixture_paths).to include("some_path")
      expect(SeedFu.fixture_paths).to include("some_path2")
    end
  end

  describe "#add_model_callback" do
    let(:metadata) do
      metadata = Plugin::Metadata.new
      metadata.name = "test"
      metadata
    end

    let(:plugin_instance) do
      plugin = Plugin::Instance.new(nil, "/tmp/test.rb")
      plugin.metadata = metadata
      plugin
    end

    it "should add the right callback" do
      called = 0

      plugin_instance.add_model_callback(User, :after_create) { called += 1 }

      user = Fabricate(:user)

      expect(called).to eq(1)

      user.update!(username: "some_username")

      expect(called).to eq(1)
    end

    it "should add the right callback with options" do
      called = 0

      plugin_instance.add_model_callback(User, :after_commit, on: :create) { called += 1 }

      user = Fabricate(:user)

      expect(called).to eq(1)

      user.update!(username: "some_username")

      expect(called).to eq(1)
    end
  end

  describe "locales" do
    let!(:plugin) { plugin_from_fixtures("custom_locales") }
    let(:plugin_path) { File.dirname(plugin.path) }
    let(:plural) do
      {
        keys: %i[one few other],
        rule:
          lambda do |n|
            return :one if n == 1
            return :few if n < 10
            :other
          end,
      }
    end

    def register_locale(locale, opts)
      plugin.register_locale(locale, opts)
      plugin.activate!

      DiscoursePluginRegistry.locales[locale]
    end

    it "enables the registered locales only on activate" do
      plugin.register_locale("foo_BAR", name: "Foo", nativeName: "Foo Bar", plural: plural)
      plugin.register_locale("tup", name: "Tupi", nativeName: "Tupi", fallbackLocale: "pt_BR")
      expect(DiscoursePluginRegistry.locales.count).to eq(0)

      plugin.activate!

      expect(DiscoursePluginRegistry.locales.count).to eq(2)
    end

    it "allows finding the locale by string and symbol" do
      register_locale("foo_BAR", name: "Foo", nativeName: "Foo Bar", plural: plural)

      expect(DiscoursePluginRegistry.locales).to have_key(:foo_BAR)
      expect(DiscoursePluginRegistry.locales).to have_key("foo_BAR")
    end

    it "correctly registers a new locale" do
      locale = register_locale("foo_BAR", name: "Foo", nativeName: "Foo Bar", plural: plural)

      expect(DiscoursePluginRegistry.locales.count).to eq(1)
      expect(DiscoursePluginRegistry.locales).to have_key(:foo_BAR)

      expect(locale[:fallbackLocale]).to be_nil
      expect(locale[:moment_js]).to eq(
        ["foo_BAR", "#{plugin_path}/lib/javascripts/locale/moment_js/foo_BAR.js"],
      )
      expect(locale[:moment_js_timezones]).to eq(
        ["foo_BAR", "#{plugin_path}/lib/javascripts/locale/moment_js_timezones/foo_BAR.js"],
      )
      expect(locale[:plural]).to eq(plural.with_indifferent_access)

      expect(Rails.configuration.assets.precompile).to include("locales/foo_BAR.js")

      expect(JsLocaleHelper.find_moment_locale(["foo_BAR"])).to eq(locale[:moment_js])
      expect(JsLocaleHelper.find_moment_locale(["foo_BAR"], timezone_names: true)).to eq(
        locale[:moment_js_timezones],
      )
    end

    it "correctly registers a new locale using a fallback locale" do
      locale = register_locale("tup", name: "Tupi", nativeName: "Tupi", fallbackLocale: "pt_BR")

      expect(DiscoursePluginRegistry.locales.count).to eq(1)
      expect(DiscoursePluginRegistry.locales).to have_key(:tup)

      expect(locale[:fallbackLocale]).to eq("pt_BR")
      expect(locale[:moment_js]).to eq(
        ["pt-br", "#{Rails.root}/vendor/assets/javascripts/moment-locale/pt-br.js"],
      )
      expect(locale[:moment_js_timezones]).to eq(
        ["pt", "#{Rails.root}/vendor/assets/javascripts/moment-timezone-names-locale/pt.js"],
      )
      expect(locale[:plural]).to be_nil

      expect(Rails.configuration.assets.precompile).to include("locales/tup.js")

      expect(JsLocaleHelper.find_moment_locale(["tup"])).to eq(locale[:moment_js])
    end

    it "correctly registers a new locale when some files exist in core" do
      locale = register_locale("tlh", name: "Klingon", nativeName: "tlhIngan Hol", plural: plural)

      expect(DiscoursePluginRegistry.locales.count).to eq(1)
      expect(DiscoursePluginRegistry.locales).to have_key(:tlh)

      expect(locale[:fallbackLocale]).to be_nil
      expect(locale[:moment_js]).to eq(
        ["tlh", "#{Rails.root}/vendor/assets/javascripts/moment-locale/tlh.js"],
      )
      expect(locale[:plural]).to eq(plural.with_indifferent_access)

      expect(Rails.configuration.assets.precompile).to include("locales/tlh.js")

      expect(JsLocaleHelper.find_moment_locale(["tlh"])).to eq(locale[:moment_js])
    end

    it "does not register a new locale when the fallback locale does not exist" do
      register_locale("bar", name: "Bar", nativeName: "Bar", fallbackLocale: "foo")
      expect(DiscoursePluginRegistry.locales.count).to eq(0)
    end

    %w[
      config/locales/client.foo_BAR.yml
      config/locales/server.foo_BAR.yml
      lib/javascripts/locale/moment_js/foo_BAR.js
      assets/locales/foo_BAR.js.erb
    ].each do |path|
      it "does not register a new locale when #{path} is missing" do
        path = "#{plugin_path}/#{path}"
        File.stubs("exist?").returns(false)
        File.stubs("exist?").with(regexp_matches(/#{Regexp.quote(plugin_path)}.*/)).returns(true)
        File.stubs("exist?").with(path).returns(false)

        register_locale("foo_BAR", name: "Foo", nativeName: "Foo Bar", plural: plural)
        expect(DiscoursePluginRegistry.locales.count).to eq(0)
      end
    end
  end

  describe "#register_reviewable_type" do
    subject(:register_reviewable_type) { plugin_instance.register_reviewable_type(new_type) }

    context "when the provided class inherits from `Reviewable`" do
      let(:new_type) { Class.new(Reviewable) }

      it "adds the provided class to the existing types" do
        expect { register_reviewable_type }.to change { Reviewable.types.size }.by(1)
        expect(Reviewable.types).to include(new_type)
      end

      context "when the plugin is disabled" do
        before do
          register_reviewable_type
          plugin_instance.stubs(:enabled?).returns(false)
        end

        it "does not return the new type" do
          expect(Reviewable.types).not_to be_blank
          expect(Reviewable.types).not_to include(new_type)
        end
      end
    end

    context "when the provided class does not inherit from `Reviewable`" do
      let(:new_type) { Class }

      it "does not add the provided class to the existing types" do
        expect { register_reviewable_type }.not_to change { Reviewable.types }
        expect(Reviewable.types).not_to be_blank
      end
    end
  end

  describe "#extend_list_method" do
    subject(:extend_list) do
      plugin_instance.extend_list_method(UserHistory, :staff_actions, %i[new_action another_action])
    end

    it "adds the provided values to the provided method on the provided class" do
      expect { extend_list }.to change { UserHistory.staff_actions.size }.by(2)
      expect(UserHistory.staff_actions).to include(:new_action, :another_action)
    end

    context "when the plugin is disabled" do
      before do
        extend_list
        plugin_instance.stubs(:enabled?).returns(false)
      end

      it "does not return the provided values" do
        expect(UserHistory.staff_actions).not_to be_blank
        expect(UserHistory.staff_actions).not_to include(:new_action, :another_action)
      end
    end
  end

  describe "#register_emoji" do
    before { Plugin::CustomEmoji.clear_cache }

    after { Plugin::CustomEmoji.clear_cache }

    it "allows to register an emoji" do
      Plugin::Instance.new.register_emoji("foo", "/foo/bar.png")

      custom_emoji = Emoji.custom.first

      expect(custom_emoji.name).to eq("foo")
      expect(custom_emoji.url).to eq("/foo/bar.png")
      expect(custom_emoji.group).to eq(Emoji::DEFAULT_GROUP)
    end

    it "allows to register an emoji with a group" do
      Plugin::Instance.new.register_emoji("bar", "/baz/bar.png", "baz")

      custom_emoji = Emoji.custom.first

      expect(custom_emoji.name).to eq("bar")
      expect(custom_emoji.url).to eq("/baz/bar.png")
      expect(custom_emoji.group).to eq("baz")
    end

    it "sanitizes emojis' names" do
      Plugin::Instance.new.register_emoji("?", "/baz/bar.png", "baz")
      Plugin::Instance.new.register_emoji("?test?!!", "/foo/bar.png", "baz")
      Plugin::Instance.new.register_emoji("+1", "/foo/bar.png", "baz")
      Plugin::Instance.new.register_emoji("test!-1", "/foo/bar.png", "baz")

      expect(Emoji.custom.first.name).to eq("_")
      expect(Emoji.custom.second.name).to eq("_test_")
      expect(Emoji.custom.third.name).to eq("+1")
      expect(Emoji.custom.fourth.name).to eq("test_-1")
    end
  end

  describe "#replace_flags" do
    after do
      PostActionType.replace_flag_settings(nil)
      Flag.reset_flag_settings!
    end

    let(:original_flags) { PostActionType.flag_settings }

    it "adds a new flag" do
      highest_flag_id = ReviewableScore.types.values.max
      flag_name = :new_flag

      plugin_instance.replace_flags(settings: original_flags) do |settings, next_flag_id|
        settings.add(next_flag_id, flag_name)
      end

      expect(PostActionType.flag_settings.flag_types.keys).to include(flag_name)
      expect(PostActionType.flag_settings.flag_types.values.max).to eq(highest_flag_id + 1)
    end

    it "adds a new score type after adding a new flag" do
      highest_flag_id = ReviewableScore.types.values.max
      new_score_type = :new_score_type

      plugin_instance.replace_flags(
        settings: original_flags,
        score_type_names: [new_score_type],
      ) { |settings, next_flag_id| settings.add(next_flag_id, :new_flag) }

      expect(PostActionType.flag_settings.flag_types.values.max).to eq(highest_flag_id + 1)
      expect(ReviewableScore.types.keys).to include(new_score_type)
      expect(ReviewableScore.types.values.max).to eq(highest_flag_id + 2)
    end
  end

  describe "#add_api_key_scope" do
    after { DiscoursePluginRegistry.reset! }

    it "adds a custom api key scope" do
      actions = %w[admin/groups#create]
      plugin_instance.add_api_key_scope(:groups, create: { actions: actions })

      expect(ApiKeyScope.scope_mappings.dig(:groups, :create, :actions)).to contain_exactly(
        *actions,
      )
    end
  end

  describe "#add_directory_column" do
    let!(:plugin) { Plugin::Instance.new }

    before { DirectoryItem.clear_plugin_queries }

    after { DirectoryColumn.clear_plugin_directory_columns }

    describe "with valid column name" do
      let(:column_name) { "random_c" }

      before do
        DB.exec("ALTER TABLE directory_items ADD COLUMN IF NOT EXISTS #{column_name} integer")
      end

      after do
        DB.exec("ALTER TABLE directory_items DROP COLUMN IF EXISTS #{column_name}")
        DiscourseEvent.all_off("before_directory_refresh")
      end

      it "creates a directory column record when directory items are refreshed" do
        plugin.add_directory_column(
          column_name,
          query: "SELECT COUNT(*) FROM users",
          icon: "recycle",
        )
        expect(
          DirectoryColumn.find_by(name: column_name, icon: "recycle", enabled: false),
        ).not_to be_present

        DirectoryItem.refresh!
        expect(
          DirectoryColumn.find_by(name: column_name, icon: "recycle", enabled: false),
        ).to be_present
      end
    end

    it "errors when the column_name contains invalid characters" do
      expect {
        plugin.add_directory_column("Capital", query: "SELECT COUNT(*) FROM users", icon: "recycle")
      }.to raise_error(RuntimeError)

      expect {
        plugin.add_directory_column(
          "has space",
          query: "SELECT COUNT(*) FROM users",
          icon: "recycle",
        )
      }.to raise_error(RuntimeError)

      expect {
        plugin.add_directory_column(
          "has_number_1",
          query: "SELECT COUNT(*) FROM users",
          icon: "recycle",
        )
      }.to raise_error(RuntimeError)
    end
  end

  describe "#register_site_categories_callback" do
    fab!(:category)

    it "adds a callback to the Site#categories" do
      instance = Plugin::Instance.new

      site_guardian = Guardian.new

      instance.register_site_categories_callback do |categories, guardian|
        categories.each { |category| category[:test_field] = "test" }

        expect(guardian).to eq(site_guardian)
      end

      site = Site.new(site_guardian)

      expect(site.categories.first[:test_field]).to eq("test")
    ensure
      Site.clear_cache
      Site.categories_callbacks.clear
    end
  end

  describe "#register_notification_consolidation_plan" do
    let(:plugin) { Plugin::Instance.new }
    fab!(:topic)

    after { DiscoursePluginRegistry.reset_register!(:notification_consolidation_plans) }

    it "fails when the received object is not a consolidation plan" do
      expect { plugin.register_notification_consolidation_plan(Object.new) }.to raise_error(
        ArgumentError,
      )
    end

    it "registers a consolidation plan and uses it" do
      plan =
        Notifications::ConsolidateNotifications.new(
          from: Notification.types[:code_review_commit_approved],
          to: Notification.types[:code_review_commit_approved],
          threshold: 1,
          consolidation_window: 1.minute,
          unconsolidated_query_blk: ->(notifications, _data) do
            notifications.where("(data::json ->> 'consolidated') IS NULL")
          end,
          consolidated_query_blk: ->(notifications, _data) do
            notifications.where("(data::json ->> 'consolidated') IS NOT NULL")
          end,
        ).set_mutations(
          set_data_blk: ->(notification) { notification.data_hash.merge(consolidated: true) },
        )

      plugin.register_notification_consolidation_plan(plan)

      create_notification!
      create_notification!

      expect(commit_approved_notifications.count).to eq(1)
      consolidated_notification = commit_approved_notifications.last
      expect(consolidated_notification.data_hash[:consolidated]).to eq(true)
    end

    def commit_approved_notifications
      Notification.where(
        user: topic.user,
        notification_type: Notification.types[:code_review_commit_approved],
      )
    end

    def create_notification!
      Notification.consolidate_or_create!(
        notification_type: Notification.types[:code_review_commit_approved],
        topic_id: topic.id,
        user: topic.user,
        data: {
        },
      )
    end
  end

  describe "#register_email_unsubscriber" do
    let(:plugin) { Plugin::Instance.new }

    after { DiscoursePluginRegistry.reset_register!(:email_unsubscribers) }

    it "doesn't let you override core unsubscribers" do
      expect {
        plugin.register_email_unsubscriber(UnsubscribeKey::ALL_TYPE, Object)
      }.to raise_error(ArgumentError)
    end

    it "finds the plugin's custom unsubscriber" do
      new_unsubscriber_type = "new_type"
      key = UnsubscribeKey.new(unsubscribe_key_type: new_unsubscriber_type)
      CustomUnsubscriber = Class.new(EmailControllerHelper::BaseEmailUnsubscriber)

      plugin.register_email_unsubscriber(new_unsubscriber_type, CustomUnsubscriber)

      expect(UnsubscribeKey.get_unsubscribe_strategy_for(key).class).to eq(CustomUnsubscriber)
    end
  end

  describe "#register_stat" do
    let(:plugin) { Plugin::Instance.new }

    after { DiscoursePluginRegistry.reset! }

    it "registers an about stat group correctly" do
      stats = { :last_day => 1, "7_days" => 10, "30_days" => 100, :count => 1000 }
      plugin.register_stat("some_group") { stats }
      expect(Stat.all_stats.with_indifferent_access).to match(
        hash_including(
          some_group_last_day: 1,
          some_group_7_days: 10,
          some_group_30_days: 100,
          some_group_count: 1000,
        ),
      )
    end

    it "does not allow duplicate named stat groups" do
      stats = { :last_day => 1, "7_days" => 10, "30_days" => 100, :count => 1000 }
      plugin.register_stat("some_group") { stats }
      plugin.register_stat("some_group") { stats }
      expect(DiscoursePluginRegistry.stats.count).to eq(1)
    end
  end

  describe "#register_user_destroyer_on_content_deletion_callback" do
    let(:plugin) { Plugin::Instance.new }

    after { DiscoursePluginRegistry.reset_register!(:user_destroyer_on_content_deletion_callbacks) }

    fab!(:user)

    it "calls the callback when the UserDestroyer runs with the delete_posts opt set to true" do
      callback_called = false

      cb = Proc.new { callback_called = true }
      plugin.register_user_destroyer_on_content_deletion_callback(cb)

      UserDestroyer.new(Discourse.system_user).destroy(user, { delete_posts: true })

      expect(callback_called).to eq(true)
    end

    it "doesn't run the callback when delete_posts opt is not true" do
      callback_called = false

      cb = Proc.new { callback_called = true }
      plugin.register_user_destroyer_on_content_deletion_callback(cb)

      UserDestroyer.new(Discourse.system_user).destroy(user, {})

      expect(callback_called).to eq(false)
    end
  end

  describe "#register_modifier" do
    let(:plugin) { Plugin::Instance.new }

    after { DiscoursePluginRegistry.clear_modifiers! }

    it "allows modifier registration" do
      plugin.register_modifier(:magic_sum_modifier) { |a, b| a + b }

      sum = DiscoursePluginRegistry.apply_modifier(:magic_sum_modifier, 1, 2)
      expect(sum).to eq(3)
    end
  end
end
