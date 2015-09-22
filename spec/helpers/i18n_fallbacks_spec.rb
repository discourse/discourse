require 'spec_helper'

describe 'freedom patch for I18n::Backend::Fallbacks' do
  before do
    SiteSetting.default_locale = 'de'
    I18n.locale = :de

    store_translations(:en, :foo => 'Foo in :en', :bar => 'Bar in :en')
    store_translations(:de, :bar => 'Bar in :de')
    store_translations(:'de-AT', :baz => 'Baz in :de-AT')
  end

  def store_translations(locale, data)
    I18n.backend.store_translations(locale, data)
  end

  describe '#exists?' do
    it 'returns true when a key is given that exists in the default locale' do
      expect(I18n.exists?(:bar)).to be true
    end

    it 'returns true when a key is given that exists in a fallback locale of the default locale' do
      expect(I18n.exists?(:foo)).to be true
    end

    it 'returns false when a non-existing key is given' do
      expect(I18n.exists?(:bogus)).to be false
    end

    it 'returns true when an existing key and an existing locale is given' do
      expect(I18n.exists?(:foo, :en)).to be true
      expect(I18n.exists?(:bar, :de)).to be true
      expect(I18n.exists?(:baz, :'de-AT')).to be true
    end

    it 'returns false when a non-existing key and an existing locale is given' do
      expect(I18n.exists?(:bogus, :en)).to be false
      expect(I18n.exists?(:bogus, :de)).to be false
      expect(I18n.exists?(:bogus, :'de-AT')).to be false
    end

    it 'returns true when a key is given which is missing from the given locale and exists in a fallback locale' do
      expect(I18n.exists?(:foo, :de)).to be true
      expect(I18n.exists?(:foo, :'de-AT')).to be true
    end

    it 'returns true when a key is given which is missing from the given locale and all its fallback locales' do
      expect(I18n.exists?(:baz, :de)).to be false
      expect(I18n.exists?(:bogus, :'de-AT')).to be false
    end
  end
end
