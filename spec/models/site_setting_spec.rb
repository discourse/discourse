require 'spec_helper'

describe SiteSetting do

  describe "int setting" do 
    before :all do 
      SiteSetting.setting(:test_setting, 77)
      SiteSetting.refresh!
    end

    it 'should have a key in all_settings' do
      SiteSetting.all_settings.detect {|s| s[:setting] == :test_setting }.should be_present
    end

    it "should have the correct desc" do 
      I18n.expects(:t).with("site_settings.test_setting").returns("test description")
      SiteSetting.description(:test_setting).should == "test description"
    end
    
    it "should have the correct default" do 
      SiteSetting.test_setting.should == 77
    end

    describe "when overidden" do 
      before :all do 
        SiteSetting.test_setting = 100
      end

      after :all do 
        SiteSetting.remove_override!(:test_setting)
      end
    
      it "should have the correct override" do 
        SiteSetting.test_setting.should == 100
      end

    end
  end

  describe "string setting" do 
    before :all do 
      SiteSetting.setting(:test_str, "str")
      SiteSetting.refresh!
    end

    it "should have the correct default" do 
      SiteSetting.test_str.should == "str"
    end
  end 

  describe "bool setting" do 
    before :all do 
      SiteSetting.setting(:test_hello?, false) 
      SiteSetting.refresh!
    end

    it "should have the correct default" do 
      SiteSetting.test_hello?.should == false
    end
    
    it "should be overridable" do
      SiteSetting.test_hello = true
      SiteSetting.refresh!
      SiteSetting.test_hello?.should == true
    end

    it "should coerce true strings to true" do 
      SiteSetting.test_hello = "true"
      SiteSetting.refresh!
      SiteSetting.test_hello?.should == true
    end

    it "should coerce all other strings to false" do 
      SiteSetting.test_hello = "f"
      SiteSetting.refresh!
      SiteSetting.test_hello?.should == false
    end
  end

  describe 'call_discourse_hub?' do
    it 'should be true when enforce_global_nicknames is true and discourse_org_access_key is set' do
      SiteSetting.enforce_global_nicknames = true
      SiteSetting.discourse_org_access_key = 'asdfasfsafd'
      SiteSetting.refresh!
      SiteSetting.call_discourse_hub?.should == true
    end

    it 'should be false when enforce_global_nicknames is false and discourse_org_access_key is set' do
      SiteSetting.enforce_global_nicknames = false
      SiteSetting.discourse_org_access_key = 'asdfasfsafd'
      SiteSetting.refresh!
      SiteSetting.call_discourse_hub?.should == false
    end

    it 'should be false when enforce_global_nicknames is true and discourse_org_access_key is not set' do
      SiteSetting.enforce_global_nicknames = true
      SiteSetting.discourse_org_access_key = ''
      SiteSetting.refresh!
      SiteSetting.call_discourse_hub?.should == false
    end

    it 'should be false when enforce_global_nicknames is false and discourse_org_access_key is not set' do
      SiteSetting.enforce_global_nicknames = false
      SiteSetting.discourse_org_access_key = ''
      SiteSetting.refresh!
      SiteSetting.call_discourse_hub?.should == false
    end
  end

end
