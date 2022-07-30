# frozen_string_literal: true

RSpec.describe ThemeJavascriptCompiler do

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
      ctx.eval(File.open("#{Rails.root}/app/assets/javascripts/node_modules/handlebars/dist/handlebars.js").read)
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

    it "doesn't duplicate number parameter inside {{each}}" do
      expect(compiler.compile("{{#each item as |test test2|}}{{theme-setting 'setting_key'}}{{/each}}")).
        to include('{"name":"theme-setting","hash":{},"hashTypes":{},"hashContexts":{},"types":["NumberLiteral","StringLiteral"]')
      # Fail would be if theme-setting is defined with types:["NumberLiteral","NumberLiteral","StringLiteral"]
    end
  end

  describe ThemeJavascriptCompiler::EmberTemplatePrecompiler do
    # For the Ember (Glimmer) templates, serverside rendering is not trivial,
    # so we compile the expected result with the standard compiler and compare to the theme compiler
    let(:standard_compiler) { Barber::Ember::Precompiler.new }
    let(:theme_compiler) { described_class.new(theme_id) }

    def theme_compile(template)
      compiled = theme_compiler.compile(template)
      data = JSON.parse(compiled)
      JSON.parse(data["block"])
    end

    def standard_compile(template)
      compiled = standard_compiler.compile(template)
      data = JSON.parse(compiled)
      JSON.parse(data["block"])
    end

    it 'adds the theme id to the helpers' do
      expect(
        theme_compile "{{theme-prefix 'translation_key'}}"
      ).to eq(
        standard_compile "{{theme-prefix #{theme_id} 'translation_key'}}"
      )

      expect(
        theme_compile "{{theme-i18n 'translation_key'}}"
      ).to eq(
        standard_compile "{{theme-i18n #{theme_id} 'translation_key'}}"
      )

      expect(
        theme_compile "{{theme-setting 'setting_key'}}"
      ).to eq(
        standard_compile "{{theme-setting #{theme_id} 'setting_key'}}"
      )

      # # Works when used inside other statements
      expect(
        theme_compile "{{dummy-helper (theme-prefix 'translation_key')}}"
      ).to eq(
        standard_compile "{{dummy-helper (theme-prefix #{theme_id} 'translation_key')}}"
      )
    end
  end

  describe "#append_raw_template" do
    let(:compiler) { ThemeJavascriptCompiler.new(1, 'marks') }
    it 'uses the correct template paths' do
      template = "<h1>hello</h1>"
      name = "/path/to/templates1"
      compiler.append_raw_template("#{name}.raw", template)
      expect(compiler.content.to_s).to include("addRawTemplate(\"#{name}\"")

      name = "/path/to/templates2"
      compiler.append_raw_template("#{name}.hbr", template)
      expect(compiler.content.to_s).to include("addRawTemplate(\"#{name}\"")

      name = "/path/to/templates3"
      compiler.append_raw_template("#{name}.hbs", template)
      expect(compiler.content.to_s).to include("addRawTemplate(\"#{name}.hbs\"")
    end
  end

  describe "#append_ember_template" do
    let(:compiler) { ThemeJavascriptCompiler.new(1, 'marks') }
    it 'prepends `javascripts/` to template name if it is not prepended' do
      compiler.append_ember_template("/connectors/blah-1", "{{var}}")
      expect(compiler.content.to_s).to include('Ember.TEMPLATES["javascripts/connectors/blah-1"]')

      compiler.append_ember_template("connectors/blah-2", "{{var}}")
      expect(compiler.content.to_s).to include('Ember.TEMPLATES["javascripts/connectors/blah-2"]')

      compiler.append_ember_template("javascripts/connectors/blah-3", "{{var}}")
      expect(compiler.content.to_s).to include('Ember.TEMPLATES["javascripts/connectors/blah-3"]')
    end
  end
end
