require 'rails_helper'

describe TranslationOverride do

  it "upserts values" do
    TranslationOverride.upsert!('en', 'some.key', 'some value')

    ovr = TranslationOverride.where(locale: 'en', translation_key: 'some.key').first
    expect(ovr).to be_present
    expect(ovr.value).to eq('some value')
  end

  it "stores js for a message format key" do
    TranslationOverride.upsert!('en', 'some.key_MF', '{NUM_RESULTS, plural, one {1 result} other {many} }')

    ovr = TranslationOverride.where(locale: 'en', translation_key: 'some.key_MF').first
    expect(ovr).to be_present
    expect(ovr.compiled_js).to match(/function/)
  end

end

