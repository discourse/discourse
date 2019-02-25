require 'rails_helper'
require 'i18n/backend/discourse_i18n'
require 'translation_override'

describe I18n::Backend::DiscourseI18n do

  let(:backend) { I18n::Backend::DiscourseI18n.new }

  before do
    backend.reload!
    backend.store_translations(:en, foo: 'Foo in :en', bar: 'Bar in :en', wat: 'Hello %{count}')
    backend.store_translations(:en, items: { one: 'one item', other: '%{count} items' })
    backend.store_translations(:de, bar: 'Bar in :de')
    backend.store_translations(:ru, baz: 'Baz in :ru')
    backend.store_translations(:en, link: '[text](url)')
  end

  after do
    backend.reload!
  end

  it 'translates the basics as expected' do
    expect(backend.translate(:en, 'foo')).to eq('Foo in :en')
    expect(backend.translate(:en, 'items', count: 1)).to eq('one item')
    expect(backend.translate(:en, 'items', count: 3)).to eq('3 items')
    expect(backend.translate(:en, 'wat', count: 3)).to eq('Hello 3')
  end

  it 'can be searched by key or value' do
    expect(backend.search(:en, 'fo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'foo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'Foo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'hello')).to eq('wat' => 'Hello %{count}')
    expect(backend.search(:en, 'items.one')).to eq('items.one' => 'one item')
    expect(backend.search(:en, '](')).to eq('link' => '[text](url)')
  end

  it 'can return multiple results' do
    results = backend.search(:en, 'item')

    expect(results['items.one']).to eq('one item')
    expect(results['items.other']).to eq('%{count} items')
  end

  describe 'fallbacks' do
    it 'uses fallback locales for searching' do
      expect(backend.search(:de, 'bar')).to eq('bar' => 'Bar in :de')
      expect(backend.search(:de, 'foo')).to eq('foo' => 'Foo in :en')
    end

    it 'uses fallback locales for translating' do
      expect(backend.translate(:de, 'bar')).to eq('Bar in :de')
      expect(backend.translate(:de, 'foo')).to eq('Foo in :en')
    end

    it 'uses default_locale as fallback when key exists' do
      SiteSetting.default_locale = 'ru'
      expect(backend.translate(:de, 'bar')).to eq('Bar in :de')
      expect(backend.translate(:de, 'baz')).to eq('Baz in :ru')
      expect(backend.translate(:de, 'foo')).to eq('Foo in :en')
    end
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
      expect(backend.exists?(:ru, :baz)).to eq(true)
    end

    it 'returns false when a non-existing key and an existing locale is given' do
      expect(backend.exists?(:en, :bogus)).to eq(false)
      expect(backend.exists?(:de, :bogus)).to eq(false)
      expect(backend.exists?(:ru, :bogus)).to eq(false)
    end

    it 'returns true when a key is given which is missing from the given locale and exists in a fallback locale' do
      expect(backend.exists?(:de, :foo)).to eq(true)
      expect(backend.exists?(:ru, :foo)).to eq(true)
    end

    it 'returns true when a key is given which is missing from the given locale and all its fallback locales' do
      expect(backend.exists?(:de, :baz)).to eq(false)
      expect(backend.exists?(:ru, :bogus)).to eq(false)
    end
  end
end
