require "rails_helper"

describe "translate accelerator" do
  after do
    I18n.reload!
  end

  it "overrides for both string and symbol keys" do
    key = "user.email.not_allowed"
    text_overriden = "foobar"

    expect(I18n.t(key)).to be_present

    TranslationOverride.upsert!("en", key, text_overriden)

    expect(I18n.t(key)).to eq(text_overriden)
    expect(I18n.t(key.to_sym)).to eq(text_overriden)
  end

  describe '.overrides_by_locale' do
    it 'should cache overrides for each locale' do
      TranslationOverride.upsert!('en', 'got', "summer")
      TranslationOverride.upsert!('zh_TW', 'got', "冬季")
      I18n.backend.store_translations(:en, got: 'winter')

      I18n.overrides_by_locale('en')
      I18n.overrides_by_locale('zh_TW')

      expect(I18n.instance_variable_get(:@overrides_by_site)).to eq(
        "default" => {
          "en" => { "got" => "summer" },
          "zh_TW" => { "got" => "冬季" }
        }
      )
    end
  end

  context "plugins" do
    before do
      DiscoursePluginRegistry.register_locale(
        "foo",
        name: "Foo",
        nativeName: "Foo Bar",
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
      I18n.backend.store_translations(:foo, items: { one: 'one item', few: 'some items', other: "%{count} items" })
      I18n.locale = :foo

      expect(I18n.t('i18n.plural.keys')).to eq([:one, :few, :other])
      expect(I18n.t('items', count: 1)).to eq('one item')
      expect(I18n.t('items', count: 3)).to eq('some items')
      expect(I18n.t('items', count: 20)).to eq('20 items')
    end
  end
end
