# frozen_string_literal: true

require 'rails_helper'

describe ThemeJavascriptCompiler do

  let(:theme_id) { 22 }

  describe ThemeJavascriptCompiler::RawTemplatePrecompiler do
    # For the raw templates, we can easily render them serverside, so let's do that

    let(:compiler) { described_class.new(theme_id) }

    let(:helpers) {
      <<~JS
      Handlebars.registerHelper('theme-prefix', function(themeId, string) {
        return `theme_translations.${themeId}.${string}`
      })
      Handlebars.registerHelper('theme-i18n', function(themeId, string) {
        return `translated(theme_translations.${themeId}.${string})`
      })
      Handlebars.registerHelper('theme-setting', function(themeId, string) {
        return `setting(${themeId}:${string})`
      })
      Handlebars.registerHelper('dummy-helper', function(string) {
        return `dummy(${string})`
      })
      JS
    }

    let(:mini_racer) {
      ctx = MiniRacer::Context.new
      ctx.eval(File.open("#{Rails.root}/vendor/assets/javascripts/handlebars.js").read)
      ctx.eval(helpers)
      ctx
    }

    def render(template)
      compiled = compiler.compile(template)
      mini_racer.eval "Handlebars.template(#{compiled.squish})({})"
    end

    it 'adds the theme id to the helpers' do
      # Works normally
      expect(render("{{theme-prefix 'translation_key'}}")).
        to eq('theme_translations.22.translation_key')
      expect(render("{{theme-i18n 'translation_key'}}")).
        to eq('translated(theme_translations.22.translation_key)')
      expect(render("{{theme-setting 'setting_key'}}")).
        to eq('setting(22:setting_key)')

      # Works when used inside other statements
      expect(render("{{dummy-helper (theme-prefix 'translation_key')}}")).
        to eq('dummy(theme_translations.22.translation_key)')
    end

    it 'works with the old settings syntax' do
      expect(render("{{themeSettings.setting_key}}")).
        to eq('setting(22:setting_key)')

      # Works when used inside other statements
      expect(render("{{dummy-helper themeSettings.setting_key}}")).
        to eq('dummy(setting(22:setting_key))')
    end

    it "doesn't duplicate number parameter inside {{each}}" do
      expect(compiler.compile("{{#each item as |test test2|}}{{theme-setting 'setting_key'}}{{/each}}")).
        to include('{"name":"theme-setting","hash":{},"hashTypes":{},"hashContexts":{},"types":["NumberLiteral","StringLiteral"]')
      # Fail would be if theme-setting is defined with types:["NumberLiteral","NumberLiteral","StringLiteral"]
    end
  end

  describe ThemeJavascriptCompiler::EmberTemplatePrecompiler do
    # For the Ember (Glimmer) templates, serverside rendering is not trivial,
    # so check the compiled JSON against known working output
    let(:compiler) { described_class.new(theme_id) }
    let(:helper_opcode) do
      append = statement("{{dummy-helper 1}}")[0]
      helper = append[1]
      helper[0]
    end

    def statement(template)
      compiled = compiler.compile(template)
      data = JSON.parse(compiled)
      block = JSON.parse(data["block"])
      block["statements"]
    end

    it 'adds the theme id to the helpers' do
      expect(statement("{{theme-prefix 'translation_key'}}")).
        to eq([[1, [helper_opcode, "theme-prefix", [22, "translation_key"], nil], false]])
      expect(statement("{{theme-i18n 'translation_key'}}")).
        to eq([[1, [helper_opcode, "theme-i18n", [22, "translation_key"], nil], false]])
      expect(statement("{{theme-setting 'setting_key'}}")).
        to eq([[1, [helper_opcode, "theme-setting", [22, "setting_key"], nil], false]])

      # Works when used inside other statements
      expect(statement("{{dummy-helper (theme-prefix 'translation_key')}}")).
        to eq([[1, [helper_opcode, "dummy-helper", [[helper_opcode, "theme-prefix", [22, "translation_key"], nil]], nil], false]])
    end

    it 'works with the old settings syntax' do
      expect(statement("{{themeSettings.setting_key}}")).
        to eq([[1, [helper_opcode, "theme-setting", [22, "setting_key"], [["deprecated"], [true]]], false]])

      # Works when used inside other statements
      expect(statement("{{dummy-helper themeSettings.setting_key}}")).
        to eq([[1, [helper_opcode, "dummy-helper", [[helper_opcode, "theme-setting", [22, "setting_key"], [["deprecated"], [true]]]], nil], false]])
    end
  end

end
