require 'spec_helper'
require_dependency 'js_locale_helper'

describe JsLocaleHelper do
  it 'should be able to generate translations' do
    JsLocaleHelper.output_locale('en').length.should > 0
  end

  def setup_message_format(format)
    @ctx = V8::Context.new
    @ctx.eval('MessageFormat = {locale: {}};')
    @ctx.load(Rails.root + 'lib/javascripts/locale/en.js')
    compiled = JsLocaleHelper.compile_message_format('en', format)
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
    localize(NUM_RESULTS: 1).should == '1 result'
    localize(NUM_RESULTS: 2).should == '2 results'
  end

  it 'handles double plurals' do
    setup_message_format('{NUM_RESULTS, plural,
            one {1 result}
          other {# results}
        } and {NUM_APPLES, plural,
            one {1 apple}
          other {# apples}
        }')


    localize(NUM_RESULTS: 1, NUM_APPLES: 2).should == '1 result and 2 apples'
    localize(NUM_RESULTS: 2, NUM_APPLES: 1).should == '2 results and 1 apple'
  end

  it 'handles select' do
    setup_message_format('{GENDER, select, male {He} female {She} other {They}} read a book')
    localize(GENDER: 'male').should == 'He read a book'
    localize(GENDER: 'female').should == 'She read a book'
    localize(GENDER: 'none').should == 'They read a book'
  end

  it 'can strip out message formats' do
    hash = {"a" => "b", "c" => { "d" => {"f_MF" => "bob"} }}
    JsLocaleHelper.strip_out_message_formats!(hash).should == {"c.d.f_MF" => "bob"}
    hash["c"]["d"].should == {}
  end

  it 'handles message format special keys' do
    ctx = V8::Context.new
    ctx.eval("I18n = {};")
    ctx.eval(JsLocaleHelper.output_locale('en',
    {
      "en" =>
      {
        "js" => {
          "hello" => "world",
          "test_MF" => "{HELLO} {COUNT, plural, one {1 duck} other {# ducks}}",
          "error_MF" => "{{BLA}",
          "simple_MF" => "{COUNT, plural, one {1} other {#}}"
        }
      }
    }))

    ctx.eval('I18n.translations')["en"]["js"]["hello"].should == "world"
    ctx.eval('I18n.translations')["en"]["js"]["test_MF"].should be_nil

    ctx.eval('I18n.messageFormat("test_MF", { HELLO: "hi", COUNT: 3 })').should == "hi 3 ducks"
    ctx.eval('I18n.messageFormat("error_MF", { HELLO: "hi", COUNT: 3 })').should =~ /Invalid Format/
    ctx.eval('I18n.messageFormat("missing", {})').should =~ /missing/
    ctx.eval('I18n.messageFormat("simple_MF", {})').should =~ /COUNT/ # error
  end

  it 'load pluralizations rules before precompile' do
    message = JsLocaleHelper.compile_message_format('ru', 'format')
    message.should_not match 'Plural Function not found'
  end

  LocaleSiteSetting.values.each do |locale|
    it "generates valid date helpers for #{locale[:value]} locale" do
      js = JsLocaleHelper.output_locale(locale[:value])
      ctx = V8::Context.new
      ctx.load(Rails.root + 'app/assets/javascripts/locales/i18n.js')
      ctx.eval(js)
    end
  end

end
