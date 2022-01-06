# frozen_string_literal: true

require "rails_helper"

describe "translate accelerator" do
  before do
    @original_i18n_load_path = I18n.load_path.dup
    I18n.load_path += Dir["#{Rails.root}/spec/fixtures/i18n/translate_accelerator.*.yml"]
    I18n.reload!
  end

  after do
    I18n.load_path = @original_i18n_load_path
    I18n.reload!
  end

  def override_translation(locale, key, value)
    expect(I18n.exists?(key, locale)).to eq(true)
    override = TranslationOverride.upsert!(locale, key, value)
    expect(override.persisted?).to eq(true)
  end

  it "supports raising if requested, and cache bypasses" do
    expect { I18n.t('i_am_an_unknown_key99', raise: true) }.to raise_error(I18n::MissingTranslationData)

    orig = I18n.t('i_am_an_unknown_key99')

    expect(I18n.t('i_am_an_unknown_key99').object_id).to eq(orig.object_id)
    expect(I18n.t('i_am_an_unknown_key99')).to eq("translation missing: en.i_am_an_unknown_key99")
  end

  it "returns the correct language" do
    expect(I18n.t('foo', locale: :en)).to eq('Foo in :en')
    expect(I18n.t('foo', locale: :de)).to eq('Foo in :de')

    I18n.with_locale(:en) do
      expect(I18n.t('foo')).to eq('Foo in :en')
    end

    I18n.with_locale(:de) do
      expect(I18n.t('foo')).to eq('Foo in :de')
    end
  end

  it "converts language keys to symbols" do
    expect(I18n.t('foo', locale: :en)).to eq('Foo in :en')
    expect(I18n.t('foo', locale: "en")).to eq('Foo in :en')

    expect(I18n.instance_variable_get(:@loaded_locales)).to contain_exactly(:en)
  end

  it "overrides for both string and symbol keys" do
    key = 'user.email.not_allowed'
    text_overridden = 'foobar'

    expect(I18n.t(key)).to be_present

    override_translation('en', key, text_overridden)

    expect(I18n.t(key)).to eq(text_overridden)
    expect(I18n.t(key.to_sym)).to eq(text_overridden)
  end

  describe ".overrides_by_locale" do
    it "should cache overrides for each locale" do
      override_translation('en', 'got', 'summer')
      override_translation('zh_TW', 'got', '冬季')

      I18n.overrides_by_locale('en')
      I18n.overrides_by_locale('zh_TW')

      expect(I18n.instance_variable_get(:@overrides_by_site)).to eq(
        'default' => {
          en: { 'got' => 'summer' },
          zh_TW: { 'got' => '冬季' }
        }
      )
    end
  end

  context "plugins" do
    before do
      DiscoursePluginRegistry.register_locale(
        'foo',
        name: 'Foo',
        nativeName: 'Foo Bar',
        plural: {
          keys: [:one, :few, :other],
          rule: lambda do |n|
            return :one if n == 1
            return :few if n < 10
            :other
          end
        }
      )

      LocaleSiteSetting.reset!
      I18n.reload!
    end

    after do
      DiscoursePluginRegistry.reset!
      LocaleSiteSetting.reset!
    end

    it "loads plural rules from plugins" do
      I18n.locale = :foo

      expect(I18n.t('i18n.plural.keys')).to eq([:one, :few, :other])
      expect(I18n.t('items', count: 1)).to eq('one item')
      expect(I18n.t('items', count: 3)).to eq('some items')
      expect(I18n.t('items', count: 20)).to eq('20 items')
    end
  end

  describe "with overrides" do
    before { I18n.locale = :en }

    it "returns the overridden key" do
      override_translation('en', 'foo', 'Overwritten foo')
      expect(I18n.t('foo')).to eq('Overwritten foo')

      override_translation('en', 'foo', 'new value')
      expect(I18n.t('foo')).to eq('new value')
    end

    it "returns the overridden key after switching the locale" do
      override_translation('en', 'foo', 'Overwritten foo in EN')
      override_translation('de', 'foo', 'Overwritten foo in DE')

      expect(I18n.t('foo')).to eq('Overwritten foo in EN')
      I18n.locale = :de
      expect(I18n.t('foo')).to eq('Overwritten foo in DE')
    end

    it "can be searched" do
      override_translation('en', 'wat', 'Overwritten value')
      expect(I18n.search('wat')).to include('wat' => 'Overwritten value')
      expect(I18n.search('Overwritten')).to include('wat' => 'Overwritten value')

      override_translation('en', 'wat', 'Overwritten with (parentheses)')
      expect(I18n.search('Overwritten with (')).to include('wat' => 'Overwritten with (parentheses)')
    end

    it "supports disabling" do
      orig_title = I18n.t('title')
      override_translation('en', 'title', 'overridden title')

      I18n.overrides_disabled do
        expect(I18n.t('title')).to eq(orig_title)
      end

      expect(I18n.t('title')).to eq('overridden title')
    end

    it "supports interpolation" do
      override_translation('en', 'world', 'my %{world}')
      expect(I18n.t('world', world: 'foo')).to eq('my foo')
    end

    it "supports interpolation named count" do
      override_translation('en', 'wat', 'goodbye %{count}')
      expect(I18n.t('wat', count: 123)).to eq('goodbye 123')
    end

    it "ignores interpolation named count if it is not applicable" do
      override_translation('en', 'wat', 'bar')
      expect(I18n.t('wat', count: 1)).to eq('bar')
    end

    it "supports one and other" do
      override_translation('en', 'items.one', 'one fish')
      override_translation('en', 'items.other', '%{count} fishies')
      expect(I18n.t('items', count: 13)).to eq('13 fishies')
      expect(I18n.t('items', count: 1)).to eq('one fish')
    end

    it "works with strings and symbols for non-pluralized string when count is given" do
      override_translation('en', 'fish', 'trout')
      expect(I18n.t(:fish, count: 1)).to eq('trout')
      expect(I18n.t('fish', count: 1)).to eq('trout')
    end

    it "supports one and other with fallback locale" do
      override_translation('en_GB', 'items.one', 'one fish')
      override_translation('en_GB', 'items.other', '%{count} fishies')

      I18n.with_locale(:en_GB) do
        expect(I18n.t('items', count: 13)).to eq('13 fishies')
        expect(I18n.t('items', count: 1)).to eq('one fish')
      end
    end

    it "supports one and other when only a single pluralization key is overridden" do
      override_translation('en', 'keys.magic.other', 'no magic keys')
      expect(I18n.t('keys.magic', count: 1)).to eq('one magic key')
      expect(I18n.t('keys.magic', count: 2)).to eq('no magic keys')
    end

    it "returns the overridden text when falling back" do
      override_translation('en', 'got', 'summer')
      expect(I18n.t('got')).to eq('summer')
      expect(I18n.with_locale(:zh_TW) { I18n.t('got') }).to eq('summer')

      override_translation('en', 'throne', '%{title} is the new queen')
      expect(I18n.t('throne', title: 'snow')).to eq('snow is the new queen')
      expect(I18n.with_locale(:en) { I18n.t('throne', title: 'snow') })
        .to eq('snow is the new queen')
    end

    it "returns override if it exists before falling back" do
      expect(I18n.t('got', default: '')).to eq('winter')
      expect(I18n.with_locale(:ru) { I18n.t('got', default: '') }).to eq('winter')

      override_translation('ru', 'got', 'summer')
      expect(I18n.t('got', default: '')).to eq('winter')
      expect(I18n.with_locale(:ru) { I18n.t('got', default: '') }).to eq('summer')
    end

    it "does not affect ActiveModel::Naming#human" do
      Fish = Class.new(ActiveRecord::Base)

      override_translation('en', 'fish', 'fake fish')
      expect(Fish.model_name.human).to eq('Fish')
    end
  end

  context "translation precedence" do
    def translation_should_equal(key, expected_value)
      I18n.locale = :en
      expect(I18n.t(key, locale: :de)).to eq(expected_value)
      expect(I18n.search(key, locale: :de)[key]).to eq(expected_value)

      I18n.locale = :de
      expect(I18n.t(key)).to eq(expected_value)
      expect(I18n.search(key)[key]).to eq(expected_value)
    end

    context "with existing translations in current locale and fallback locale" do
      context "with overrides in both locales" do
        it "should return the override from the current locale" do
          override_translation("de", "foo", "Override of foo in :de")
          override_translation("en", "foo", "Override of foo in :en")
          translation_should_equal("foo", "Override of foo in :de")
        end
      end

      context "with override only in current locale" do
        it "should return the override from the current locale" do
          override_translation("de", "foo", "Override of foo in :de")
          translation_should_equal("foo", "Override of foo in :de")
        end
      end

      context "with override only in fallback locale" do
        it "should return the translation from the current locale" do
          override_translation("en", "foo", "Override of foo in :en")
          translation_should_equal("foo", "Foo in :de")
        end
      end

      context "with no overrides" do
        it "should return the translation from the current locale" do
          translation_should_equal("foo", "Foo in :de")
        end
      end
    end

    context "with existing translation in fallback locale" do
      context "with overrides in both locales" do
        it "should return the override from the current locale" do
          override_translation("de", "fish", "Override of fish in :de")
          override_translation("en", "fish", "Override of fish in :en")
          translation_should_equal("fish", "Override of fish in :de")
        end
      end

      context "with override only in current locale" do
        it "should return the override from the current locale" do
          override_translation("de", "fish", "Override of fish in :de")
          translation_should_equal("fish", "Override of fish in :de")
        end
      end

      context "with override only in fallback locale" do
        it "should return the translation from the current locale" do
          override_translation("en", "fish", "Override of fish in :en")
          translation_should_equal("fish", "Override of fish in :en")
        end
      end

      context "with no overrides" do
        it "should return the translation from the fallback locale" do
          translation_should_equal("fish", "original fish")
        end
      end
    end
  end
end
