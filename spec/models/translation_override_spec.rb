require 'rails_helper'

describe TranslationOverride do
  context 'validations' do
    describe '#value' do
      before do
        I18n.backend.store_translations(:en, some_key: '%{first} %{second}')
      end

      describe 'when interpolation keys are missing' do
        it 'should not be valid' do
          translation_override = TranslationOverride.upsert!(
            I18n.locale, 'some_key', '%{key} %{omg}'
          )

          expect(translation_override.errors.full_messages).to include(I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
            keys: 'key, omg'
          ))
        end

        context 'when custom interpolation keys are included' do
          it 'should be valid' do
            translation_override = TranslationOverride.upsert!(
              I18n.locale,
              'some_key',
              "#{described_class::CUSTOM_INTERPOLATION_KEYS_WHITELIST['user_notifications.user_'].join(", ")} %{something}"
            )

            expect(translation_override.errors.full_messages).to include(I18n.t(
              'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
              keys: 'something'
            ))
          end
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
    TranslationOverride.upsert!('ru', 'some.key_MF', '{NUM_RESULTS, plural, one {1 result} other {many} }')

    ovr = TranslationOverride.where(locale: 'ru', translation_key: 'some.key_MF').first
    expect(ovr).to be_present
    expect(ovr.compiled_js).to start_with('function')
    expect(ovr.compiled_js).to_not match(/Invalid Format/i)
  end

end
