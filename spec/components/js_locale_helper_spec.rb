require 'rails_helper'
require_dependency 'js_locale_helper'
require 'mini_racer'

describe JsLocaleHelper do

  module StubLoadTranslations
    def set_translations(locale, translations)
      @loaded_translations ||= HashWithIndifferentAccess.new
      @loaded_translations[locale] = translations
    end

    def clear_cache!
      @loaded_translations = nil
      @loaded_merges = nil
    end
  end

  JsLocaleHelper.extend StubLoadTranslations

  after do
    I18n.locale = :en
    JsLocaleHelper.clear_cache!
  end

  describe "#output_locale" do

    it "doesn't change the cached translations hash" do
      I18n.locale = :fr
      expect(JsLocaleHelper.output_locale('fr').length).to be > 0
      expect(JsLocaleHelper.translations_for('fr')['fr'].keys).to contain_exactly("js", "admin_js", "wizard_js")
    end

  end

  context "message format" do
    def message_format_filename(locale)
      Rails.root + "lib/javascripts/locale/#{locale}.js"
    end

    def setup_message_format(format)
      filename = message_format_filename('en')
      compiled = JsLocaleHelper.compile_message_format(filename, 'en', format)

      @ctx = MiniRacer::Context.new
      @ctx.eval('MessageFormat = {locale: {}};')
      @ctx.load(filename)
      @ctx.eval("var test = #{compiled}")
    end

    def localize(opts)
      @ctx.eval("test(#{opts.to_json})")
    end

    it 'handles plurals' do
      setup_message_format('{NUM_RESULTS, plural,
              one {1 result}
            other {# results}
          }')
      expect(localize(NUM_RESULTS: 1)).to eq('1 result')
      expect(localize(NUM_RESULTS: 2)).to eq('2 results')
    end

    it 'handles double plurals' do
      setup_message_format('{NUM_RESULTS, plural,
              one {1 result}
            other {# results}
          } and {NUM_APPLES, plural,
              one {1 apple}
            other {# apples}
          }')

      expect(localize(NUM_RESULTS: 1, NUM_APPLES: 2)).to eq('1 result and 2 apples')
      expect(localize(NUM_RESULTS: 2, NUM_APPLES: 1)).to eq('2 results and 1 apple')
    end

    it 'handles select' do
      setup_message_format('{GENDER, select, male {He} female {She} other {They}} read a book')
      expect(localize(GENDER: 'male')).to eq('He read a book')
      expect(localize(GENDER: 'female')).to eq('She read a book')
      expect(localize(GENDER: 'none')).to eq('They read a book')
    end

    it 'can strip out message formats' do
      hash = { "a" => "b", "c" => { "d" => { "f_MF" => "bob" } } }
      expect(JsLocaleHelper.strip_out_message_formats!(hash)).to eq("c.d.f_MF" => "bob")
      expect(hash["c"]["d"]).to eq({})
    end

    it 'handles message format special keys' do
      JsLocaleHelper.set_translations('en',         "en" => {
          "js" => {
            "hello" => "world",
            "test_MF" => "{HELLO} {COUNT, plural, one {1 duck} other {# ducks}}",
            "error_MF" => "{{BLA}",
            "simple_MF" => "{COUNT, plural, one {1} other {#}}"
          },
          "admin_js" => {
            "foo_MF" => "{HELLO} {COUNT, plural, one {1 duck} other {# ducks}}"
          }
        })

      ctx = MiniRacer::Context.new
      ctx.eval("I18n = { pluralizationRules: {} };")
      ctx.eval(JsLocaleHelper.output_locale('en'))

      expect(ctx.eval('I18n.translations["en"]["js"]["hello"]')).to eq("world")
      expect(ctx.eval('I18n.translations["en"]["js"]["test_MF"]')).to eq(nil)

      expect(ctx.eval('I18n.messageFormat("test_MF", { HELLO: "hi", COUNT: 3 })')).to eq("hi 3 ducks")
      expect(ctx.eval('I18n.messageFormat("error_MF", { HELLO: "hi", COUNT: 3 })')).to match(/Invalid Format/)
      expect(ctx.eval('I18n.messageFormat("missing", {})')).to match(/missing/)
      expect(ctx.eval('I18n.messageFormat("simple_MF", {})')).to match(/COUNT/) # error
      expect(ctx.eval('I18n.messageFormat("foo_MF", { HELLO: "hi", COUNT: 4 })')).to eq("hi 4 ducks")
    end

    it 'load pluralizations rules before precompile' do
      message = JsLocaleHelper.compile_message_format(message_format_filename('ru'), 'ru', 'format')
      expect(message).not_to match 'Plural Function not found'
    end
  end

  it 'performs fallbacks to english if a translation is not available' do
    JsLocaleHelper.set_translations('en',       "en" => {
        "js" => {
          "only_english"      => "1-en",
          "english_and_site"  => "3-en",
          "english_and_user"  => "5-en",
          "all_three"         => "7-en",
        }
      })

    JsLocaleHelper.set_translations('ru',       "ru" => {
        "js" => {
          "only_site"         => "2-ru",
          "english_and_site"  => "3-ru",
          "site_and_user"     => "6-ru",
          "all_three"         => "7-ru",
        }
      })

    JsLocaleHelper.set_translations('uk',       "uk" => {
        "js" => {
          "only_user"         => "4-uk",
          "english_and_user"  => "5-uk",
          "site_and_user"     => "6-uk",
          "all_three"         => "7-uk",
        }
      })

    expected = {
      "none"              => "[uk.js.none]",
      "only_english"      => "1-en",
      "only_site"         => "2-ru",
      "english_and_site"  => "3-ru",
      "only_user"         => "4-uk",
      "english_and_user"  => "5-uk",
      "site_and_user"     => "6-uk",
      "all_three"         => "7-uk",
    }

    SiteSetting.default_locale = 'ru'
    I18n.locale = :uk

    ctx = MiniRacer::Context.new
    ctx.eval('var window = this;')
    ctx.load(Rails.root + 'app/assets/javascripts/locales/i18n.js')
    ctx.eval(JsLocaleHelper.output_locale(I18n.locale))
    ctx.eval('I18n.defaultLocale = "ru";')

    expect(ctx.eval('I18n.translations.en.js').keys).to contain_exactly("only_english")
    expect(ctx.eval('I18n.translations.ru.js').keys).to contain_exactly("only_site", "english_and_site")
    expect(ctx.eval('I18n.translations.uk.js').keys).to contain_exactly("all_three", "english_and_user", "only_user", "site_and_user")

    expected.each do |key, expect|
      expect(ctx.eval("I18n.t(#{"js.#{key}".inspect})")).to eq(expect)
    end
  end

  LocaleSiteSetting.values.each do |locale|
    it "generates valid date helpers for #{locale[:value]} locale" do
      js = JsLocaleHelper.output_locale(locale[:value])
      ctx = MiniRacer::Context.new
      ctx.eval('var window = this;')
      ctx.load(Rails.root + 'app/assets/javascripts/locales/i18n.js')
      ctx.eval(js)
    end

    it "finds moment.js locale file for #{locale[:value]}" do
      content = JsLocaleHelper.moment_locale(locale[:value])

      if (locale[:value] == 'en')
        expect(content).to eq('')
      else
        expect(content).to_not eq('')
      end
    end
  end

end
