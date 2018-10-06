require "rails_helper"

describe "translate accelerator" do
  before(:all) do
    @original_i18n_load_path = I18n.load_path.dup
    I18n.load_path += Dir["#{Rails.root}/spec/fixtures/i18n/translate_accelerator.*.yml"]
    I18n.reload!
  end

  after(:all) do
    I18n.load_path = @original_i18n_load_path
    I18n.reload!
  end

  after do
    I18n.reload!
  end

  def override_translation(locale, key, value)
    expect(I18n.exists?(key, locale)).to eq(true)
    override = TranslationOverride.upsert!(locale, key, value)
    expect(override.persisted?).to eq(true)
  end

  it "overrides for both string and symbol keys" do
    key = 'user.email.not_allowed'
    text_overriden = 'foobar'

    expect(I18n.t(key)).to be_present

    override_translation('en', key, text_overriden)

    expect(I18n.t(key)).to eq(text_overriden)
    expect(I18n.t(key.to_sym)).to eq(text_overriden)
  end

  describe ".overrides_by_locale" do
    it "should cache overrides for each locale" do
      override_translation('en', 'got', 'summer')
      override_translation('zh_TW', 'got', '冬季')

      I18n.overrides_by_locale('en')
      I18n.overrides_by_locale('zh_TW')

      expect(I18n.instance_variable_get(:@overrides_by_site)).to eq(
        'default' => {
          'en' => { 'got' => 'summer' },
          'zh_TW' => { 'got' => '冬季' }
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

    it "supports one and other when only a single pluralization key is overridden" do
      override_translation('en', 'keys.magic.other', 'no magic keys')
      expect(I18n.t('keys.magic', count: 1)).to eq('one magic key')
      expect(I18n.t('keys.magic', count: 2)).to eq('no magic keys')
    end

    it "returns the overriden text when falling back" do
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

    describe "client json" do
      it "is empty by default" do
        expect(I18n.client_overrides_json('en')).to eq('{}')
      end

      it "doesn't return server overrides" do
        override_translation('en', 'foo', 'bar')
        expect(I18n.client_overrides_json('en')).to eq('{}')
      end

      it "returns client overrides" do
        override_translation('en', 'js.foo', 'bar')
        override_translation('en', 'admin_js.beep', 'boop')
        json = ::JSON.parse(I18n.client_overrides_json('en'))

        expect(json).to be_present
        expect(json['js.foo']).to eq('bar')
        expect(json['admin_js.beep']).to eq('boop')
      end
    end
  end
end
