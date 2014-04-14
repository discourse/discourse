require 'spec_helper'
require_dependency 'site_setting_extension'
require_dependency 'site_settings/local_process_provider'

describe SiteSettingExtension do

  class FakeSettings
    extend SiteSettingExtension
    self.provider = SiteSettings::LocalProcessProvider.new
  end

  class FakeSettings2
    extend SiteSettingExtension
    self.provider = FakeSettings.provider
  end

  let :settings do
    FakeSettings
  end

  let :settings2 do
    FakeSettings2
  end

  describe "refresh!" do

    it "will reset to default if provider vanishes" do
      settings.setting(:hello, 1)
      settings.hello = 100
      settings.hello.should == 100

      settings.provider.clear
      settings.refresh!

      settings.hello.should == 1
    end

    it "will set to new value if provider changes" do

      settings.setting(:hello, 1)
      settings.hello = 100
      settings.hello.should == 100

      settings.provider.save(:hello, 99, SiteSetting.types[:fixnum] )
      settings.refresh!

      settings.hello.should == 99
    end

    it "Publishes changes cross sites" do
      settings.setting(:hello, 1)
      settings2.setting(:hello, 1)

      settings.hello = 100

      settings2.refresh!
      settings2.hello.should == 100

      settings.hello = 99

      settings2.refresh!
      settings2.hello.should == 99
    end

  end

  describe "multisite" do
    it "has no db cross talk" do
      settings.setting(:hello, 1)
      settings.hello = 100
      settings.provider.current_site = "boom"
      settings.hello.should == 1
    end
  end

  describe "int setting" do
    before do
      settings.setting(:test_setting, 77)
      settings.refresh!
    end

    it "should have a key in all_settings" do
      settings.all_settings.detect {|s| s[:setting] == :test_setting }.should be_present
    end

    it "should have the correct desc" do
      I18n.expects(:t).with("site_settings.test_setting").returns("test description")
      settings.description(:test_setting).should == "test description"
    end

    it "should have the correct default" do
      settings.test_setting.should == 77
    end

    context "when overidden" do
      after :each do
        settings.remove_override!(:test_setting)
      end

      it "should have the correct override" do
        settings.test_setting = 100
        settings.test_setting.should == 100
      end

      it "should coerce correct string to int" do
        settings.test_setting = "101"
        settings.test_setting.should.eql? 101
      end

      it "should coerce incorrect string to 0" do
        settings.test_setting = "pie"
        settings.test_setting.should.eql? 0
      end

			it "should not set default when reset" do
        settings.test_setting = 100
        settings.setting(:test_setting, 77)
        settings.refresh!
        settings.test_setting.should_not == 77
      end

      it "can be overridden with set" do
        settings.set("test_setting", 12)
        settings.test_setting.should == 12
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
      settings.test_str.should == "str"
    end

    context "when overridden" do
      after :each do
        settings.remove_override!(:test_str)
      end

      it "should coerce int to string" do
        settings.test_str = 100
        settings.test_str.should.eql? "100"
      end

      it "can be overridden with set" do
        settings.set("test_str", "hi")
        settings.test_str.should == "hi"
      end
    end
  end

  describe "bool setting" do
    before do
      settings.setting(:test_hello?, false)
      settings.refresh!
    end

    it "should have the correct default" do
      settings.test_hello?.should == false
    end

    context "when overridden" do
      after do
        settings.remove_override!(:test_hello?)
      end

      it "should have the correct override" do
        settings.test_hello = true
        settings.test_hello?.should == true
      end

      it "should coerce true strings to true" do
        settings.test_hello = "true"
        settings.test_hello?.should.eql? true
      end

      it "should coerce all other strings to false" do
        settings.test_hello = "f"
        settings.test_hello?.should.eql? false
      end

			it "should not set default when reset" do
        settings.test_hello = true
        settings.setting(:test_hello?, false)
        settings.refresh!
        settings.test_hello?.should_not == false
      end

      it "can be overridden with set" do
        settings.set("test_hello", true)
        settings.test_hello?.should == true
      end
    end
  end

  # describe 'enum setting' do
  #   before do
  #     @enum_class = Enum.new(:test) # not a valid site setting class
  #     @enum_class.stubs(:translate_names?).returns(false)
  #     settings.setting(:test_enum, 'en', enum: @enum_class)  # would never do this in practice
  #     settings.refresh!
  #   end

  #   it 'should have the correct default' do
  #     expect(settings.test_enum).to eq('en')
  #   end

  #   it 'should not hose all_settings' do
  #     settings.all_settings.detect {|s| s[:setting] == :test_enum }.should be_present
  #   end

  #   context 'when overridden' do

  #     it 'stores valid values' do
  #       @enum_class.expects(:valid_value?).with('fr').returns(true)
  #       settings.test_enum = 'fr'
  #       expect(settings.test_enum).to eq('fr')
  #     end

  #     it 'rejects invalid values' do
  #       @enum_class.expects(:valid_value?).with('gg').returns(false)
  #       expect {settings.test_enum = 'gg' }.to raise_error(Discourse::InvalidParameters)
  #     end
  #   end
  # end

  describe 'a setting with a category' do
    before do
      settings.setting(:test_setting, 88, {category: :tests})
      settings.refresh!
    end

    it "should return the category in all_settings" do
      settings.all_settings.find {|s| s[:setting] == :test_setting }[:category].should == :tests
    end

    context "when overidden" do
      after :each do
        settings.remove_override!(:test_setting)
      end

      it "should have the correct override" do
        settings.test_setting = 101
        settings.test_setting.should == 101
      end

      it "should still have the correct category" do
        settings.test_setting = 102
        settings.all_settings.find {|s| s[:setting] == :test_setting }[:category].should == :tests
      end
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

end
