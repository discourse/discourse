require 'rails_helper'
require_dependency 'site_setting_extension'
require_dependency 'site_settings/local_process_provider'

describe SiteSettingExtension do

  # We disable message bus here to avoid a large amount
  # of uneeded messaging, tests are careful to call refresh
  # when they need to.
  #
  # DistributedCache used by locale handler can under certain
  # cases take a tiny bit to stabalize.
  #
  # TODO: refactor SiteSettingExtension not to rely on statics in
  # DefaultsProvider
  #
  before do
    MessageBus.off
  end

  after do
    MessageBus.on
  end

  describe '#types' do
    context "verify enum sequence" do
      before do
        @types = SiteSetting.types
      end

      it "'string' should be at 1st position" do
        expect(@types[:string]).to eq(1)
      end

      it "'value_list' should be at 12th position" do
        expect(@types[:value_list]).to eq(12)
      end
    end
  end

  let :provider_local do
    SiteSettings::LocalProcessProvider.new
  end

  def new_settings(provider)
    # we want to avoid leaking a big pile of MessageBus subscriptions here (1 per class)
    # so we set listen_for_changes to false
    Class.new do
      extend SiteSettingExtension
      self.listen_for_changes = false
      self.provider = provider
    end
  end

  let :settings do
    new_settings(provider_local)
  end

  let :settings2 do
    new_settings(provider_local)
  end

  it "Does not leak state cause changes are not linked" do
    t1 = Thread.new do
      5.times do
        settings = new_settings(SiteSettings::LocalProcessProvider.new)
        settings.setting(:title, 'test')
        settings.title = 'title1'
        expect(settings.title).to eq 'title1'

      end
    end

    t2 = Thread.new do
      5.times do
        settings = new_settings(SiteSettings::LocalProcessProvider.new)
        settings.setting(:title, 'test')
        settings.title = 'title2'
        expect(settings.title).to eq 'title2'
      end
    end

    t1.join
    t2.join
  end

  describe "refresh!" do

    it "will reset to default if provider vanishes" do
      settings.setting(:hello, 1)
      settings.hello = 100
      expect(settings.hello).to eq(100)

      settings.provider.clear
      settings.refresh!

      expect(settings.hello).to eq(1)
    end

    it "will set to new value if provider changes" do

      settings.setting(:hello, 1)
      settings.hello = 100
      expect(settings.hello).to eq(100)

      settings.provider.save(:hello, 99, SiteSetting.types[:integer])
      settings.refresh!

      expect(settings.hello).to eq(99)
    end

    it "publishes changes cross sites" do
      settings.setting(:hello, 1)
      settings2.setting(:hello, 1)

      settings.hello = 100

      settings2.refresh!
      expect(settings2.hello).to eq(100)

      settings.hello = 99

      settings2.refresh!
      expect(settings2.hello).to eq(99)
    end

  end

  describe "multisite" do
    it "has no db cross talk" do
      settings.setting(:hello, 1)
      settings.hello = 100
      settings.provider.current_site = "boom"
      expect(settings.hello).to eq(1)
    end
  end

  describe "int setting" do
    before do
      settings.setting(:test_setting, 77)
      settings.refresh!
    end

    it "should have a key in all_settings" do
      expect(settings.all_settings.detect { |s| s[:setting] == :test_setting }).to be_present
    end

    it "should have the correct desc" do
      I18n.expects(:t).with("site_settings.test_setting").returns("test description")
      expect(settings.description(:test_setting)).to eq("test description")
    end

    it "should have the correct default" do
      expect(settings.test_setting).to eq(77)
    end

    context "when overidden" do
      after :each do
        settings.remove_override!(:test_setting)
      end

      it "should have the correct override" do
        settings.test_setting = 100
        expect(settings.test_setting).to eq(100)
      end

      it "should coerce correct string to int" do
        settings.test_setting = "101"
        expect(settings.test_setting).to eq(101)
      end

      it "should coerce incorrect string to 0" do
        settings.test_setting = "pie"
        expect(settings.test_setting).to eq(0)
      end

      it "should not set default when reset" do
        settings.test_setting = 100
        settings.setting(:test_setting, 77)
        settings.refresh!
        expect(settings.test_setting).not_to eq(77)
      end

      it "can be overridden with set" do
        settings.set("test_setting", 12)
        expect(settings.test_setting).to eq(12)
      end

      it "should publish changes to clients" do
        settings.setting("test_setting", 100)
        settings.setting("test_setting", nil, client: true)

        message = MessageBus.track_publish('/client_settings') do
          settings.test_setting = 88
        end.first

        expect(message).to be_present
      end
    end
  end

  describe "remove_override" do
    before do
      settings.setting(:test_override, "test")
      settings.refresh!
    end
    it "correctly nukes overrides" do
      settings.test_override = "bla"
      settings.remove_override!(:test_override)
      expect(settings.test_override).to eq("test")
    end
  end

  describe "string setting" do
    before do
      settings.setting(:test_str, "str")
      settings.refresh!
    end

    it "should have the correct default" do
      expect(settings.test_str).to eq("str")
    end

    context "when overridden" do
      after :each do
        settings.remove_override!(:test_str)
      end

      it "should coerce int to string" do
        settings.test_str = 100
        expect(settings.test_str).to eq("100")
      end

      it "can be overridden with set" do
        settings.set("test_str", "hi")
        expect(settings.test_str).to eq("hi")
      end
    end
  end

  describe "string setting with regex" do
    it "Supports custom validation errors" do
      settings.setting(:test_str, "bob", regex: "hi", regex_error: "oops")
      settings.refresh!

      begin
        settings.test_str = "a"
      rescue Discourse::InvalidParameters => e
        message = e.message
      end

      expect(message).to match(/oops/)
    end
  end

  describe "bool setting" do
    before do
      settings.setting(:test_hello?, false)
      settings.refresh!
    end

    it "should have the correct default" do
      expect(settings.test_hello?).to eq(false)
    end

    context "when overridden" do
      after do
        settings.remove_override!(:test_hello?)
      end

      it "should have the correct override" do
        settings.test_hello = true
        expect(settings.test_hello?).to eq(true)
      end

      it "should coerce true strings to true" do
        settings.test_hello = "true"
        expect(settings.test_hello?).to be(true)
      end

      it "should coerce all other strings to false" do
        settings.test_hello = "f"
        expect(settings.test_hello?).to be(false)
      end

      it "should not set default when reset" do
        settings.test_hello = true
        settings.setting(:test_hello?, false)
        settings.refresh!
        expect(settings.test_hello?).not_to eq(false)
      end

      it "can be overridden with set" do
        settings.set("test_hello", true)
        expect(settings.test_hello?).to eq(true)
      end
    end
  end

  describe 'int enum' do
    class TestIntEnumClass
      def self.valid_value?(v)
        true
      end
      def self.values
        [1, 2, 3]
      end
    end

    it 'should coerce correctly' do
      settings.setting(:test_int_enum, 1, enum: TestIntEnumClass)
      settings.test_int_enum = "2"
      settings.refresh!
      expect(settings.defaults[:test_int_enum]).to eq(1)
      expect(settings.test_int_enum).to eq(2)
    end

  end

  describe 'enum setting' do

    class TestEnumClass
      def self.valid_value?(v)
        self.values.include?(v)
      end
      def self.values
        ['en']
      end
      def self.translate_names?
        false
      end
    end

    let :test_enum_class do
      TestEnumClass
    end

    before do
      settings.setting(:test_enum, 'en', enum: test_enum_class)
      settings.refresh!
    end

    it 'should have the correct default' do
      expect(settings.test_enum).to eq('en')
    end

    it 'should not hose all_settings' do
      expect(settings.all_settings.detect { |s| s[:setting] == :test_enum }).to be_present
    end

    it 'should report error when being set other values' do
      expect { settings.test_enum = 'not_in_enum' }.to raise_error(Discourse::InvalidParameters)
    end

    context 'when overridden' do
      after :each do
        settings.remove_override!(:validated_setting)
      end

      it 'stores valid values' do
        test_enum_class.expects(:valid_value?).with('fr').returns(true)
        settings.test_enum = 'fr'
        expect(settings.test_enum).to eq('fr')
      end

      it 'rejects invalid values' do
        test_enum_class.expects(:valid_value?).with('gg').returns(false)
        expect { settings.test_enum = 'gg' }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end

  describe 'a setting with a category' do
    before do
      settings.setting(:test_setting, 88, category: :tests)
      settings.refresh!
    end

    it "should return the category in all_settings" do
      expect(settings.all_settings.find { |s| s[:setting] == :test_setting }[:category]).to eq(:tests)
    end

    context "when overidden" do
      after :each do
        settings.remove_override!(:test_setting)
      end

      it "should have the correct override" do
        settings.test_setting = 101
        expect(settings.test_setting).to eq(101)
      end

      it "should still have the correct category" do
        settings.test_setting = 102
        expect(settings.all_settings.find { |s| s[:setting] == :test_setting }[:category]).to eq(:tests)
      end
    end
  end

  describe "setting with a validator" do
    before do
      settings.setting(:validated_setting, "info@example.com", type: 'email')
      settings.refresh!
    end

    after :each do
      settings.remove_override!(:validated_setting)
    end

    it "stores valid values" do
      EmailSettingValidator.any_instance.expects(:valid_value?).returns(true)
      settings.validated_setting = 'success@example.com'
      expect(settings.validated_setting).to eq('success@example.com')
    end

    it "rejects invalid values" do
      expect {
        EmailSettingValidator.any_instance.expects(:valid_value?).returns(false)
        settings.validated_setting = 'nope'
      }.to raise_error(Discourse::InvalidParameters)
      expect(settings.validated_setting).to eq("info@example.com")
    end

    it "allows blank values" do
      settings.validated_setting = ''
      expect(settings.validated_setting).to eq('')
    end
  end

  describe "set for an invalid setting name" do
    it "raises an error" do
      settings.setting(:test_setting, 77)
      settings.refresh!
      expect {
        settings.set("provider", "haxxed")
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe ".set_and_log" do
    before do
      settings.setting(:s3_secret_access_key, "old_secret_key", secret: true)
      settings.setting(:title, "Discourse v1")
      settings.refresh!
    end

    it "raises an error when set for an invalid setting name" do
      expect {
        settings.set_and_log("provider", "haxxed")
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "scrubs secret setting values from logs" do
      settings.set_and_log("s3_secret_access_key", "new_secret_key")
      expect(UserHistory.last.previous_value).to eq("[FILTERED]")
      expect(UserHistory.last.new_value).to eq("[FILTERED]")
    end

    it "works" do
      settings.set_and_log("title", "Discourse v2")
      expect(settings.title).to eq("Discourse v2")
      expect(UserHistory.last.previous_value).to eq("Discourse v1")
      expect(UserHistory.last.new_value).to eq("Discourse v2")
    end
  end

  describe "filter domain name" do
    before do
      settings.setting(:white_listed_spam_host_domains, "www.example.com")
      settings.refresh!
    end

    it "filters domain" do
      settings.set("white_listed_spam_host_domains", "http://www.discourse.org/")
      expect(settings.white_listed_spam_host_domains).to eq("www.discourse.org")
    end

    it "returns invalid domain as is, without throwing exception" do
      settings.set("white_listed_spam_host_domains", "test!url")
      expect(settings.white_listed_spam_host_domains).to eq("test!url")
    end
  end

  describe "hidden" do
    before do
      settings.setting(:superman_identity, 'Clark Kent', hidden: true)
      settings.refresh!
    end

    it "is in the `hidden_settings` collection" do
      expect(settings.hidden_settings.include?(:superman_identity)).to eq(true)
    end

    it "can be retrieved" do
      expect(settings.superman_identity).to eq("Clark Kent")
    end

    it "is not present in all_settings by default" do
      expect(settings.all_settings.find { |s| s[:setting] == :superman_identity }).to be_blank
    end

    it "is present in all_settings when we ask for hidden" do
      expect(settings.all_settings(true).find { |s| s[:setting] == :superman_identity }).to be_present
    end
  end

  describe "shadowed_by_global" do

    context "default_locale" do
      it "supports adding a default locale via a global" do
        global_setting :default_locale, 'zh_CN'
        settings.default_locale = 'en'
        expect(settings.default_locale).to eq('zh_CN')
      end
    end

    context "without global setting" do
      before do
        settings.setting(:trout_api_key, 'evil', shadowed_by_global: true)
        settings.refresh!
      end

      it "should not add the key to the shadowed_settings collection" do
        expect(settings.shadowed_settings.include?(:trout_api_key)).to eq(false)
      end

      it "can return the default value" do
        expect(settings.trout_api_key).to eq('evil')
      end

      it "can overwrite the default" do
        settings.trout_api_key = 'tophat'
        settings.refresh!
        expect(settings.trout_api_key).to eq('tophat')
      end
    end

    context "with blank global setting" do
      before do
        GlobalSetting.stubs(:nada).returns('')
        settings.setting(:nada, 'nothing', shadowed_by_global: true)
        settings.refresh!
      end

      it "should return default cause nothing is set" do
        expect(settings.nada).to eq('nothing')
      end

    end

    context "with a false override" do
      before do
        GlobalSetting.stubs(:bool).returns(false)
        settings.setting(:bool, true, shadowed_by_global: true)
        settings.refresh!
      end

      it "should return default cause nothing is set" do
        expect(settings.bool).to eq(false)
      end

      it "should not trigger any message bus work if you try to set it" do
        m = MessageBus.track_publish('/site_settings') do
          settings.bool = true
          expect(settings.bool).to eq(false)
        end
        expect(m.length).to eq(0)
      end
    end

    context "with global setting" do
      before do
        GlobalSetting.stubs(:trout_api_key).returns('purringcat')
        settings.setting(:trout_api_key, 'evil', shadowed_by_global: true)
        settings.refresh!
      end

      it "should return the global setting instead of default" do
        expect(settings.trout_api_key).to eq('purringcat')
      end

      it "should return the global setting after a refresh" do
        settings.refresh!
        expect(settings.trout_api_key).to eq('purringcat')
      end

      it "should add the key to the hidden_settings collection" do
        expect(settings.hidden_settings.include?(:trout_api_key)).to eq(true)

        ['', nil].each_with_index do |setting, index|
          GlobalSetting.stubs(:"trout_api_key_#{index}").returns(setting)
          settings.setting(:"trout_api_key_#{index}", 'evil', shadowed_by_global: true)
          settings.refresh!
          expect(settings.hidden_settings.include?(:"trout_api_key_#{index}")).to eq(false)
        end
      end

      it "should add the key to the shadowed_settings collection" do
        expect(settings.shadowed_settings.include?(:trout_api_key)).to eq(true)
      end
    end
  end

  describe "secret" do
    before do
      settings.setting(:superman_identity, 'Clark Kent', secret: true)
      settings.refresh!
    end

    it "is in the `secret_settings` collection" do
      expect(settings.secret_settings.include?(:superman_identity)).to eq(true)
    end

    it "can be retrieved" do
      expect(settings.superman_identity).to eq("Clark Kent")
    end

    it "is present in all_settings by default" do
      secret_setting = settings.all_settings.find { |s| s[:setting] == :superman_identity }
      expect(secret_setting).to be_present
      expect(secret_setting[:secret]).to eq(true)
    end
  end

  describe 'locale default overrides are respected' do
    before do
      settings.setting(:test_override, 'default', locale_default: { zh_CN: 'cn' })
      settings.refresh!
    end

    after do
      settings.remove_override!(:test_override)
    end

    it 'ensures the default cache expired after overriding the default_locale' do
      expect(settings.test_override).to eq('default')
      settings.default_locale = 'zh_CN'
      expect(settings.test_override).to eq('cn')
    end

    it 'returns the saved setting even locale default exists' do
      expect(settings.test_override).to eq('default')
      settings.default_locale = 'zh_CN'
      settings.test_override = 'saved'
      expect(settings.test_override).to eq('saved')
    end
  end

  describe '.requires_refresh?' do
    it 'always refresh default_locale always require refresh' do
      expect(settings.requires_refresh?(:default_locale)).to be_truthy
    end
  end

  describe '.default_locale' do
    it 'is always loaded' do
      expect(settings.default_locale).to eq 'en'
    end
  end

  describe '.default_locale=' do
    it 'can be changed' do
      settings.default_locale = 'zh_CN'
      expect(settings.default_locale).to eq 'zh_CN'
    end

    it 'refresh!' do
      settings.expects(:refresh!)
      settings.default_locale = 'zh_CN'
    end

    it 'expires the cache' do
      settings.default_locale = 'zh_CN'
      expect(Rails.cache.exist?(SiteSettingExtension.client_settings_cache_key)).to be_falsey
    end

    it 'refreshes the client' do
      Discourse.expects(:request_refresh!)
      settings.default_locale = 'zh_CN'
    end
  end

  describe "get_hostname" do

    it "properly extracts the hostname" do
      expect(settings.send(:get_hostname, "discourse.org")).to eq("discourse.org")
      expect(settings.send(:get_hostname, " discourse.org ")).to eq("discourse.org")
      expect(settings.send(:get_hostname, "@discourse.org")).to eq("discourse.org")
      expect(settings.send(:get_hostname, "https://discourse.org")).to eq("discourse.org")
    end

  end

end
