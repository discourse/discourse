require 'rails_helper'
require 'i18n/backend/discourse_i18n'
require 'translation_override'

describe I18n::Backend::DiscourseI18n do

  let(:backend) { I18n::Backend::DiscourseI18n.new }

  before do
    I18n.reload!
    backend.store_translations(:en, foo: 'Foo in :en', bar: 'Bar in :en', wat: "Hello %{count}")
    backend.store_translations(:en, items: { one: 'one item', other: "%{count} items" })
    backend.store_translations(:de, bar: 'Bar in :de')
    backend.store_translations(:ru, baz: 'Baz in :ru')
  end

  after do
    I18n.locale = :en
    I18n.reload!
  end

  it 'translates the basics as expected' do
    expect(backend.translate(:en, 'foo')).to eq("Foo in :en")
    expect(backend.translate(:en, 'items', count: 1)).to eq("one item")
    expect(backend.translate(:en, 'items', count: 3)).to eq("3 items")
    expect(backend.translate(:en, 'wat', count: 3)).to eq("Hello 3")
  end

  it 'can be searched by key or value' do
    expect(backend.search(:en, 'fo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'foo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'Foo')).to eq('foo' => 'Foo in :en')
    expect(backend.search(:en, 'hello')).to eq('wat' => 'Hello %{count}')
    expect(backend.search(:en, 'items.one')).to eq('items.one' => 'one item')
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

  describe 'with overrides' do
    it 'returns the overridden key' do
      TranslationOverride.upsert!('en', 'foo', 'Overwritten foo')
      expect(I18n.translate('foo')).to eq('Overwritten foo')

      TranslationOverride.upsert!('en', 'foo', 'new value')
      expect(I18n.translate('foo')).to eq('new value')
    end

    it 'returns the overridden key after switching the locale' do
      TranslationOverride.upsert!('en', 'foo', 'Overwritten foo in EN')
      TranslationOverride.upsert!('de', 'foo', 'Overwritten foo in DE')

      expect(I18n.translate('foo')).to eq('Overwritten foo in EN')
      I18n.locale = :de
      expect(I18n.translate('foo')).to eq('Overwritten foo in DE')
    end

    it "can be searched" do
      TranslationOverride.upsert!('en', 'wat', 'Overwritten value')
      expect(I18n.search('wat', backend: backend)).to eq('wat' => 'Overwritten value')
      expect(I18n.search('Overwritten', backend: backend)).to eq('wat' => 'Overwritten value')
      expect(I18n.search('Hello', backend: backend)).to eq({})
    end

    it 'supports disabling' do
      orig_title = I18n.t('title')
      TranslationOverride.upsert!('en', 'title', 'overridden title')

      I18n.overrides_disabled do
        expect(I18n.translate('title')).to eq(orig_title)
      end
      expect(I18n.translate('title')).to eq('overridden title')
    end

    it 'supports interpolation' do
      TranslationOverride.upsert!('en', 'foo', 'hello %{world}')
      I18n.backend.store_translations(:en, foo: 'bar')
      expect(I18n.translate('foo', world: 'foo')).to eq('hello foo')
    end

    it 'supports interpolation named count' do
      TranslationOverride.upsert!('en', 'wat', 'goodbye %{count}')
      I18n.backend.store_translations(:en, wat: 'bar')
      expect(I18n.translate('wat', count: 123)).to eq('goodbye 123')
    end

    it 'ignores interpolation named count if it is not applicable' do
      TranslationOverride.upsert!('en', 'test', 'goodbye')
      I18n.backend.store_translations(:en, test: 'foo')
      I18n.backend.store_translations(:en, wat: 'bar')
      expect(I18n.translate('wat', count: 1)).to eq('bar')
    end

    it 'supports one and other' do
      TranslationOverride.upsert!('en', 'items.one', 'one fish')
      TranslationOverride.upsert!('en', 'items.other', '%{count} fishies')
      I18n.backend.store_translations(:en, items: { one: 'one item', other: "%{count} items" })
      expect(I18n.translate('items', count: 13)).to eq('13 fishies')
      expect(I18n.translate('items', count: 1)).to eq('one fish')
    end

    it 'supports one and other when only a single pluralization key is overridden' do
      TranslationOverride.upsert!('en', 'keys.magic.other', "no magic keys")
      I18n.backend.store_translations(:en, keys: { magic: { one: 'one magic key', other: "%{count} magic keys" } })
      expect(I18n.translate('keys.magic', count: 1)).to eq("one magic key")
      expect(I18n.translate('keys.magic', count: 2)).to eq("no magic keys")
    end

    it "returns the overriden text when falling back" do
      TranslationOverride.upsert!('en', 'got', "summer")
      I18n.backend.store_translations(:en, got: 'winter')

      expect(I18n.translate('got')).to eq('summer')
      expect(I18n.with_locale(:zh_TW) { I18n.translate('got') }).to eq('summer')

      TranslationOverride.upsert!('en', 'throne', "%{title} is the new queen")
      I18n.backend.store_translations(:en, throne: "%{title} is the new king")

      expect(I18n.t('throne', title: 'snow')).to eq('snow is the new queen')

      expect(I18n.with_locale(:en) { I18n.t('throne', title: 'snow') })
        .to eq('snow is the new queen')
    end

    it "returns override if it exists before falling back" do
      I18n.backend.store_translations(:en, got: 'winter')

      expect(I18n.translate('got', default: '')).to eq('winter')
      expect(I18n.with_locale(:ru) { I18n.translate('got', default: '') }).to eq('winter')

      TranslationOverride.upsert!('ru', 'got', "summer")
      I18n.backend.store_translations(:en, got: 'winter')

      expect(I18n.translate('got', default: '')).to eq('winter')
      expect(I18n.with_locale(:ru) { I18n.translate('got', default: '') }).to eq('summer')
    end

    it 'does not affect ActiveModel::Naming#human' do
      Fish = Class.new(ActiveRecord::Base)

      TranslationOverride.upsert!('en', 'fish', "fake fish")
      I18n.backend.store_translations(:en, fish: "original fish")

      expect(Fish.model_name.human).to eq('Fish')
    end

    describe "client json" do
      it "is empty by default" do
        expect(I18n.client_overrides_json('en')).to eq("{}")
      end

      it "doesn't return server overrides" do
        TranslationOverride.upsert!('en', 'foo', 'bar')
        expect(I18n.client_overrides_json('en')).to eq("{}")
      end

      it "returns client overrides" do
        TranslationOverride.upsert!('en', 'js.foo', 'bar')
        TranslationOverride.upsert!('en', 'admin_js.beep', 'boop')
        json = ::JSON.parse(I18n.client_overrides_json('en'))

        expect(json).to be_present
        expect(json['js.foo']).to eq('bar')
        expect(json['admin_js.beep']).to eq('boop')
      end
    end
  end

end
