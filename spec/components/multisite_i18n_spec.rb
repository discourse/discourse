require 'spec_helper'
require_dependency 'multisite_i18n'

describe MultisiteI18n do

  before do
    I18n.stubs(:t).with('test', {}).returns('default i18n')
    MultisiteI18n.stubs(:translation_or_nil).with("default.test", {}).returns(nil)
    MultisiteI18n.stubs(:translation_or_nil).with("other_site.test", {}).returns("overwritten i18n")
  end

  context "no value for a multisite key" do
    it "it returns the default i18n key" do
      MultisiteI18n.site_translate('default', 'test').should == "default i18n"
    end
  end

  context "with a value for the multisite key" do
    it "returns the overwritten value" do
      MultisiteI18n.site_translate('other_site', 'test').should == "overwritten i18n"
    end
  end

  context "when we call t, it uses the current site" do

    it "returns the original" do
      MultisiteI18n.t('test').should == 'default i18n'
    end

    it "returns the overwritten" do
      RailsMultisite::ConnectionManagement.stubs(:current_db).returns('other_site')
      MultisiteI18n.t('test').should == "overwritten i18n"
    end

  end

end
