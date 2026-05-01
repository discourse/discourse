# frozen_string_literal: true

RSpec.describe "Sendmail Settings Integration" do
  it "configures arguments as an Array, not a String (mail gem >= 2.9.0 compatibility)" do
    expect(GlobalSetting.sendmail_settings[:arguments]).to be_an(Array)
  end

  it "does not raise an error when initialising Sendmail with the default settings" do
    expect { Mail::Sendmail.new(GlobalSetting.sendmail_settings) }.not_to raise_error
  end
end
