# frozen_string_literal: true

require "discourse_js_processor"

RSpec.describe DiscourseJsProcessor do
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

  describe "Transpiler#rollup" do
    it "can rollup code" do
      sources = { "discourse/initializers/hello.gjs" => <<~JS }
          someDecorator = () => {}
          export default class MyClass {
            @someDecorator
            myMethod() {
              console.log('hello world');
            }
            <template>
              <div>template content</div>
            </template>
          }
        JS

      result = DiscourseJsProcessor::Transpiler.new.rollup(sources, {})

      code = result["code"]
      expect(code).to include('"hello world"')
      expect(code).to include("dt7948") # Decorator transform

      expect(result["map"]).not_to be_nil
    end

    it "supports decorators and class properties without error" do
      script = <<~JS.chomp
        export default class MyClass {
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

      result =
        DiscourseJsProcessor::Transpiler.new.rollup(
          { "discourse/initializers/foo.js" => script },
          {},
        )
      expect(result["code"]).to include("(()=>dt7948.n")
    end

    it "can use themePrefix in a template" do
      script = <<~JS.chomp
        themePrefix();
        export default class Foo {
          <template>{{themePrefix "bar"}}</template>
        }
      JS

      result =
        DiscourseJsProcessor::Transpiler.new.rollup(
          { "discourse/initializers/foo.gjs" => script },
          { themeId: 22 },
        )
      expect(result["code"]).to include(
        'window.moduleBroker.lookup("discourse/lib/theme-settings-store")',
      )
    end

    it "can use themePrefix not in a template" do
      script = <<~JS.chomp
        export default function foo() {
          return themePrefix("bar");
        }
      JS

      result =
        DiscourseJsProcessor::Transpiler.new.rollup(
          { "discourse/initializers/foo.js" => script },
          { themeId: 22 },
        )
      expect(result["code"]).to include(
        'window.moduleBroker.lookup("discourse/lib/theme-settings-store")',
      )
    end
  end

  it "can compile hbs" do
    template = <<~HBS.chomp
      {{log "hello world"}}
    HBS

    result =
      DiscourseJsProcessor::Transpiler.new.rollup(
        { "discourse/connectors/outlet-name/foo.hbs" => template },
        { themeId: 22 },
      )
    expect(result["code"]).to include("createTemplateFactory")
  end

  it "handles colocation" do
    js = <<~JS.chomp
      import Component from "@glimmer/component";
      export default class MyComponent extends Component {}
    JS

    template = <<~HBS.chomp
      {{log "hello world"}}
    HBS

    onlyTemplate = <<~HBS.chomp
      {{log "hello galaxy"}}
    HBS

    result =
      DiscourseJsProcessor::Transpiler.new.rollup(
        {
          "discourse/components/foo.js" => js,
          "discourse/components/foo.hbs" => template,
          "discourse/components/bar.hbs" => onlyTemplate,
        },
        { themeId: 22 },
      )

    expect(result["code"]).to include("setComponentTemplate")
    expect(result["code"]).to include(
      "bar = setComponentTemplate(__COLOCATED_TEMPLATE__, templateOnly());",
    )
    # puts result["code"]
  end
end
