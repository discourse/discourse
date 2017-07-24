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

  describe '.overrides_by_locale' do
    it 'should cache overrides for each locale' do
      TranslationOverride.upsert!('en', 'got', "summer")
      TranslationOverride.upsert!('zh_TW', 'got', "冬季")
      I18n.backend.store_translations(:en, got: 'winter')

      I18n.overrides_by_locale('en')
      I18n.overrides_by_locale('zh_TW')

      expect(I18n.instance_variable_get(:@overrides_by_site)).to eq(
        "default" => {
          "en" => { "got" => "summer" },
          "zh_TW" => { "got" => "冬季" }
        }
      )
    end
  end

end
