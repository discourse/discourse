require "rails_helper"

describe "translate accelerator" do

  it "overrides for both string and symbol keys" do
    key = "user.email.not_allowed"
    text_overriden = "foobar"

    expect(I18n.t(key)).to be_present

    TranslationOverride.upsert!("en", key, text_overriden)

    expect(I18n.t(key)).to eq(text_overriden)
    expect(I18n.t(key.to_sym)).to eq(text_overriden)
  end

end
