require 'spec_helper'
require_dependency 'site_setting_extension'
require_dependency 'site_settings/local_process_provider'

describe SiteSettingExtension do

  class FakeSettings
    extend SiteSettingExtension
    provider = SiteSettings::LocalProcessProvider
  end

  let :settings do
    FakeSettings
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
end
