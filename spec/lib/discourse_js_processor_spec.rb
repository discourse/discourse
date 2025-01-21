# frozen_string_literal: true

require "discourse_js_processor"

RSpec.describe DiscourseJsProcessor do
  describe "should_transpile?" do
    it "returns false for empty strings" do
      expect(DiscourseJsProcessor.should_transpile?(nil)).to eq(false)
      expect(DiscourseJsProcessor.should_transpile?("")).to eq(false)
    end

    it "returns false for a regular js file" do
      expect(DiscourseJsProcessor.should_transpile?("file.js")).to eq(false)
    end

    it "returns true for deprecated .es6 files" do
      expect(DiscourseJsProcessor.should_transpile?("file.es6")).to eq(true)
      expect(DiscourseJsProcessor.should_transpile?("file.js.es6")).to eq(true)
      expect(DiscourseJsProcessor.should_transpile?("file.js.es6.erb")).to eq(true)
    end
  end

  describe "skip_module?" do
    it "returns false for empty strings" do
      expect(DiscourseJsProcessor.skip_module?(nil)).to eq(false)
      expect(DiscourseJsProcessor.skip_module?("")).to eq(false)
    end

    it "returns true if the header is present" do
      expect(DiscourseJsProcessor.skip_module?("// cool comment\n// discourse-skip-module")).to eq(
        true,
      )
    end

    it "returns false if the header is not present" do
      expect(DiscourseJsProcessor.skip_module?("// just some JS\nconsole.log()")).to eq(false)
    end

    it "works end-to-end" do
      source = <<~JS.chomp
        // discourse-skip-module
        console.log("hello world");
      JS
      expect(DiscourseJsProcessor.transpile(source, "test", "test")).to eq(source)
    end
  end

  it "passes through modern JS syntaxes which are supported in our target browsers" do
    script = <<~JS.chomp
      optional?.chaining;
      const template = func`test`;
      let numericSeparator = 100_000_000;
      logicalAssignment ||= 2;
      nullishCoalescing ?? 'works';
      try {
        "optional catch binding";
      } catch {
        "works";
      }
      async function* asyncGeneratorFunction() {
        yield await Promise.resolve('a');
      }
      let a = {
        x,
        y,
        ...spreadRest
      };
    JS

    result = DiscourseJsProcessor.transpile(script, "blah", "blah/mymodule")
    expect(result).to eq <<~JS.strip
      define("blah/mymodule", [], function () {
        "use strict";

      #{script.indent(2)}
      });
    JS
  end

  it "supports decorators and class properties without error" do
    script = <<~JS.chomp
      class MyClass {
        classProperty = 1;
        #privateProperty = 1;
        #privateMethod() {
          console.log("hello world");
        }
        @decorated
        myMethod(){
        }
      }
    JS

    result = DiscourseJsProcessor.transpile(script, "blah", "blah/mymodule")
    expect(result).to include("static #_ = (() => dt7948.n")
  end

  it "correctly transpiles widget hbs" do
    result = DiscourseJsProcessor.transpile(<<~JS, "blah", "blah/mymodule")
      import hbs from "discourse/widgets/hbs-compiler";
      const template = hbs`{{somevalue}}`;
    JS
    expect(result).to eq <<~JS.strip
      define("blah/mymodule", [], function () {
        "use strict";

        const template = function (attrs, state) {
          var _r = [];
          _r.push(somevalue);
          return _r;
        };
      });
    JS
  end

  it "correctly transpiles ember hbs" do
    result = DiscourseJsProcessor.transpile(<<~JS, "blah", "blah/mymodule")
      import { hbs } from 'ember-cli-htmlbars';
      const template = hbs`{{somevalue}}`;
    JS
    expect(result).to eq <<~JS.strip
      define("blah/mymodule", ["@ember/template-factory"], function (_templateFactory) {
        "use strict";

        const template = (0, _templateFactory.createTemplateFactory)(
        /*
          {{somevalue}}
        */
        {
          "id": null,
          "block": "[[[1,[35,0]]],[],false,[\\"somevalue\\"]]",
          "moduleName": "/blah/mymodule",
          "isStrictMode": false
        });
      });
    JS
  end

  describe "Raw template theme transformations" do
    # For the raw templates, we can easily render them serverside, so let's do that

    let(:compiler) { DiscourseJsProcessor::Transpiler.new }
    let(:theme_id) { 22 }

    let(:helpers) { <<~JS }
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

    let(:mini_racer) do
      ctx = MiniRacer::Context.new
      ctx.eval(
        File.open(
          "#{Rails.root}/app/assets/javascripts/discourse/node_modules/handlebars/dist/handlebars.js",
        ).read,
      )
      ctx.eval(helpers)
      ctx
    end

    def render(template)
      compiled = compiler.compile_raw_template(template, theme_id: theme_id)
      mini_racer.eval "Handlebars.template(#{compiled.squish})({})"
    end

    it "adds the theme id to the helpers" do
      # Works normally
      expect(render("{{theme-prefix 'translation_key'}}")).to eq(
        "theme_translations.22.translation_key",
      )
      expect(render("{{theme-i18n 'translation_key'}}")).to eq(
        "translated(theme_translations.22.translation_key)",
      )
      expect(render("{{theme-setting 'setting_key'}}")).to eq("setting(22:setting_key)")

      # Works when used inside other statements
      expect(render("{{dummy-helper (theme-prefix 'translation_key')}}")).to eq(
        "dummy(theme_translations.22.translation_key)",
      )
    end

    it "doesn't duplicate number parameter inside {{each}}" do
      expect(
        compiler.compile_raw_template(
          "{{#each item as |test test2|}}{{theme-setting 'setting_key'}}{{/each}}",
          theme_id: theme_id,
        ),
      ).to include(
        '{"name":"theme-setting","hash":{},"hashTypes":{},"hashContexts":{},"types":["NumberLiteral","StringLiteral"]',
      )
      # Fail would be if theme-setting is defined with types:["NumberLiteral","NumberLiteral","StringLiteral"]
    end
  end

  describe "Ember template transformations" do
    # For the Ember (Glimmer) templates, serverside rendering is not trivial,
    # so we compile the expected result with the standard compiler and compare to the theme compiler
    let(:theme_id) { 22 }

    def theme_compile(template)
      script = <<~JS
        import { hbs } from 'ember-cli-htmlbars';
        export default hbs(#{template.to_json});
      JS
      result = DiscourseJsProcessor.transpile(script, "", "theme/blah", theme_id: theme_id)
      result.gsub(%r{/\*(.*)\*/}m, "/* (js comment stripped) */")
    end

    def standard_compile(template)
      script = <<~JS
        import { hbs } from 'ember-cli-htmlbars';
        export default hbs(#{template.to_json});
      JS
      result = DiscourseJsProcessor.transpile(script, "", "theme/blah")
      result.gsub(%r{/\*(.*)\*/}m, "/* (js comment stripped) */")
    end

    it "adds the theme id to the helpers" do
      expect(theme_compile "{{theme-prefix 'translation_key'}}").to eq(
        standard_compile "{{theme-prefix #{theme_id} 'translation_key'}}"
      )

      expect(theme_compile "{{theme-i18n 'translation_key'}}").to eq(
        standard_compile "{{theme-i18n #{theme_id} 'translation_key'}}"
      )

      expect(theme_compile "{{theme-setting 'setting_key'}}").to eq(
        standard_compile "{{theme-setting #{theme_id} 'setting_key'}}"
      )

      # Works when used inside other statements
      expect(theme_compile "{{dummy-helper (theme-prefix 'translation_key')}}").to eq(
        standard_compile "{{dummy-helper (theme-prefix #{theme_id} 'translation_key')}}"
      )
    end
  end

  describe "Transpiler#terser" do
    it "can minify code and provide sourcemaps" do
      sources = {
        "multiply.js" => "let multiply = (firstValue, secondValue) => firstValue * secondValue;",
        "add.js" => "let add = (firstValue, secondValue) => firstValue + secondValue;",
      }

      result =
        DiscourseJsProcessor::Transpiler.new.terser(
          sources,
          { sourceMap: { includeSources: true } },
        )
      expect(result.keys).to contain_exactly("code", "decoded_map", "map")

      begin
        # Check the code still works
        ctx = MiniRacer::Context.new
        ctx.eval(result["code"])
        expect(ctx.eval("multiply(2, 3)")).to eq(6)
        expect(ctx.eval("add(2, 3)")).to eq(5)
      ensure
        ctx.dispose
      end

      map = JSON.parse(result["map"])
      expect(map["sources"]).to contain_exactly(*sources.keys)
      expect(map["sourcesContent"]).to contain_exactly(*sources.values)
    end
  end
end
