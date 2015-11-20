require 'spec_helper'
require 'i18n/backend/discourse_i18n'
require 'translation_override'

describe I18n::Backend::DiscourseI18n do

  let(:backend) { I18n::Backend::DiscourseI18n.new }

  before do
    I18n.reload!
    backend.store_translations(:en, :foo => 'Foo in :en', :bar => 'Bar in :en', :wat => "Hello %{count}")
    backend.store_translations(:en, :items => {:one => 'one item', :other => "%{count} items" })
    backend.store_translations(:de, :bar => 'Bar in :de')
    backend.store_translations(:'de-AT', :baz => 'Baz in :de-AT')
  end

  after do
    I18n.reload!
  end

  it 'translates the basics as expected' do
    expect(backend.translate(:en, 'foo')).to eq("Foo in :en")
    expect(backend.translate(:en, 'items', count: 1)).to eq("one item")
    expect(backend.translate(:en, 'items', count: 3)).to eq("3 items")
    expect(backend.translate(:en, 'wat', count: 3)).to eq("Hello 3")
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
    it 'returns the overriden key' do
      TranslationOverride.upsert!('en', 'foo', 'Overwritten foo')
      expect(I18n.translate('foo')).to eq('Overwritten foo')

      TranslationOverride.upsert!('en', 'foo', 'new value')
      I18n.reload!
      expect(I18n.translate('foo')).to eq('new value')
    end

    it 'supports disabling' do
      TranslationOverride.upsert!('en', 'foo', 'meep')

      I18n.overrides_disabled do
        expect(I18n.translate('foo')).to eq('meep')
      end
    end

    it 'supports interpolation' do
      TranslationOverride.upsert!('en', 'foo', 'hello %{world}')
      expect(I18n.translate('foo', world: 'foo')).to eq('hello foo')
    end

    it 'supports interpolation named count' do
      TranslationOverride.upsert!('en', 'wat', 'goodbye %{count}')
      expect(I18n.translate('wat', count: 123)).to eq('goodbye 123')
    end

    it 'supports one and other' do
      TranslationOverride.upsert!('en', 'items.one', 'one fish')
      TranslationOverride.upsert!('en', 'items.other', '%{count} fishies')
      expect(I18n.translate('items', count: 13)).to eq('13 fishies')
      expect(I18n.translate('items', count: 1)).to eq('one fish')
    end

    describe "client json" do
      it "is empty by default" do
        expect(I18n.client_overrides_json).to eq("{}")
      end

      it "doesn't return server overrides" do
        TranslationOverride.upsert!('en', 'foo', 'bar')
        expect(I18n.client_overrides_json).to eq("{}")
      end

      it "returns client overrides" do
        TranslationOverride.upsert!('en', 'js.foo', 'bar')
        json = ::JSON.parse(I18n.client_overrides_json)

        expect(json).to be_present
        expect(json['js.foo']).to eq('bar')
      end
    end
  end

end
