require 'spec_helper'
require 'i18n/backend/discourse_i18n'
require 'translation_override'

describe I18n::Backend::DiscourseI18n do

  let(:backend) { I18n::Backend::DiscourseI18n.new }

  before do
    backend.reload!
    backend.store_translations(:en, :foo => 'Foo in :en', :bar => 'Bar in :en')
    backend.store_translations(:en, :items => {:one => 'one item', :other => "%{count} items" })
    backend.store_translations(:de, :bar => 'Bar in :de')
    backend.store_translations(:'de-AT', :baz => 'Baz in :de-AT')
  end

  it 'translates the basics as expected' do
    expect(backend.translate(:en, 'foo')).to eq("Foo in :en")
    expect(backend.translate(:en, 'items', count: 1)).to eq("one item")
    expect(backend.translate(:en, 'items', count: 3)).to eq("3 items")
  end

  describe '#exists?' do
    it 'returns true when a key is given that exists' do
      expect(backend.exists?(:de, :bar)).to eq(true)
    end

    it 'returns true when a key is given that exists in a fallback locale of the locale' do
      expect(backend.exists?(:de, :foo)).to eq(true)
    end

    it 'returns true when an existing key and an existing locale is given' do
      expect(backend.exists?(:en, :foo)).to eq(true)
      expect(backend.exists?(:de, :bar)).to eq(true)
      expect(backend.exists?(:'de-AT', :baz)).to eq(true)
    end

    it 'returns false when a non-existing key and an existing locale is given' do
      expect(backend.exists?(:en, :bogus)).to eq(false)
      expect(backend.exists?(:de, :bogus)).to eq(false)
      expect(backend.exists?(:'de-AT', :bogus)).to eq(false)
    end

    it 'returns true when a key is given which is missing from the given locale and exists in a fallback locale' do
      expect(backend.exists?(:de, :foo)).to eq(true)
      expect(backend.exists?(:'de-AT', :foo)).to eq(true)
    end

    it 'returns true when a key is given which is missing from the given locale and all its fallback locales' do
      expect(backend.exists?(:de, :baz)).to eq(false)
      expect(backend.exists?(:'de-AT', :bogus)).to eq(false)
    end
  end

  describe 'with overrides' do
    before do
      TranslationOverride.upsert!('en', 'foo', 'Overwritten foo')
    end

    it 'returns the overrided key' do
      expect(backend.translate(:en, 'foo')).to eq('Overwritten foo')

      TranslationOverride.upsert!('en', 'foo', 'new value')
      backend.reload!
      expect(backend.translate(:en, 'foo')).to eq('new value')
    end
  end

end
