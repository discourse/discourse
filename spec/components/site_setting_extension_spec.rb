require 'spec_helper'
require_dependency 'site_setting_extension'
require_dependency 'site_settings/local_process_provider'

describe SiteSettingExtension do
  let :provider_local do
    SiteSettings::LocalProcessProvider.new
  end

  def new_settings(provider)
    Class.new do
      extend SiteSettingExtension
      self.provider = provider
    end
  end

  let :settings do
    new_settings(provider_local)
  end

  let :settings2 do
    new_settings(provider_local)
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

      settings.provider.save(:hello, 99, SiteSetting.types[:fixnum] )
      settings.refresh!

      expect(settings.hello).to eq(99)
    end

    it "Publishes changes cross sites" do
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
      expect(settings.all_settings.detect {|s| s[:setting] == :test_setting }).to be_present
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
    end
  end

  describe "remove_override" do
    it "correctly nukes overrides" do
      settings.setting(:test_override, "test")
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
        skip "This test is not working on Rspec 2 even"
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
        [1,2,3]
      end
    end

    it 'should coerce correctly' do
      settings.setting(:test_int_enum, 1, enum: TestIntEnumClass)
      settings.test_int_enum = "2"
      settings.refresh!
      expect(settings.test_int_enum).to eq(2)
    end

  end

  describe 'enum setting' do

    class TestEnumClass
      def self.valid_value?(v)
        true
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
      expect(settings.all_settings.detect {|s| s[:setting] == :test_enum }).to be_present
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
        expect {settings.test_enum = 'gg' }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end

  describe 'a setting with a category' do
    before do
      settings.setting(:test_setting, 88, {category: :tests})
      settings.refresh!
    end

    it "should return the category in all_settings" do
      expect(settings.all_settings.find {|s| s[:setting] == :test_setting }[:category]).to eq(:tests)
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
        expect(settings.all_settings.find {|s| s[:setting] == :test_setting }[:category]).to eq(:tests)
      end
    end
  end

  describe "setting with a validator" do
    before do
      settings.setting(:validated_setting, "info@example.com", {type: 'email'})
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
      }.to raise_error(ArgumentError)
    end
  end

  describe "set for an invalid fixnum value" do
    it "raises an error" do
      settings.setting(:test_setting, 80)
      settings.refresh!
      expect {
        settings.set("test_setting", 9999999999999999999)
      }.to raise_error(ArgumentError)
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
      expect(settings.all_settings.find {|s| s[:setting] == :superman_identity }).to be_blank
    end

    it "is present in all_settings when we ask for hidden" do
      expect(settings.all_settings(true).find {|s| s[:setting] == :superman_identity }).to be_present
    end
  end

  describe "shadowed_by_global" do
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

      it "should add the key to the shadowed_settings collection" do
        expect(settings.shadowed_settings.include?(:trout_api_key)).to eq(true)
      end
    end
  end

end
