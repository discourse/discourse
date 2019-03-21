require 'rails_helper'
require 'i18n/backend/fallback_locale_list'

describe I18n::Backend::FallbackLocaleList do
  let(:list) { I18n::Backend::FallbackLocaleList.new }

  it 'works when default_locale is English' do
    SiteSetting.default_locale = :en

    expect(list[:ru]).to eq(%i[ru en])
    expect(list[:en]).to eq(%i[en])
  end

  it 'works when default_locale is not English' do
    SiteSetting.default_locale = :de

    expect(list[:ru]).to eq(%i[ru de en])
    expect(list[:de]).to eq(%i[de en])
    expect(list[:en]).to eq(%i[en de])
  end

  context 'when plugin registered fallback locale' do
    before do
      DiscoursePluginRegistry.register_locale('es_MX', fallbackLocale: 'es')
      DiscoursePluginRegistry.register_locale('de_AT', fallbackLocale: 'de')
    end

    after { DiscoursePluginRegistry.reset! }

    it 'works when default_locale is English' do
      SiteSetting.default_locale = :en

      expect(list[:de_AT]).to eq(%i[de_AT de en])
      expect(list[:de]).to eq(%i[de en])
      expect(list[:en]).to eq(%i[en])
    end

    it 'works when default_locale is not English' do
      SiteSetting.default_locale = :de

      expect(list[:es_MX]).to eq(%i[es_MX es de en])
      expect(list[:es]).to eq(%i[es de en])
      expect(list[:en]).to eq(%i[en de])
    end
  end
end
