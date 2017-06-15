require 'rails_helper'

describe TranslationOverride do
  context 'validations' do
    describe '#value' do
      before do
        described_class.any_instance.expects(:lookup_original_text)
          .returns('%{first} %{second}')
      end

      describe 'when interpolation keys are missing' do
        it 'should not be valid' do
          translation_override = TranslationOverride.upsert!(
            I18n.locale, 'some_key', '%{first}'
          )

          expect(translation_override.errors.full_messages).to include(I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.missing_interpolation_keys',
            keys: 'second'
          ))
        end
      end

      describe 'when interpolation keys are invalid' do
        it 'should not be valid' do
          translation_override = TranslationOverride.upsert!(
            I18n.locale, 'some_key', '%{first} %{second} %{third}'
          )

          expect(translation_override.errors.full_messages).to include(I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
            keys: 'third'
          ))
        end
      end
    end
  end

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
