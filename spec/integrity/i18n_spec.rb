require 'spec_helper'

describe "i18n integrity checks" do

  it 'should have an i18n key for all trust levels' do
    TrustLevel.all.each do |ts|
      ts.name.should_not =~ /translation missing/
    end
  end

  it "needs an i18n key (description) for each Site Setting" do
    SiteSetting.all_settings.each do |s|
      next if s[:setting] =~ /^test/
      s[:description].should_not =~ /translation missing/
    end
  end

  it "needs an i18n key (notification_types) for each Notification type" do
    Notification.types.keys.each do |type|
      I18n.t("notification_types.#{type}").should_not =~ /translation missing/
    end
  end


end
