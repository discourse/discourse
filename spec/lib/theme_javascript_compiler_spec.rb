# frozen_string_literal: true

RSpec.describe ThemeJavascriptCompiler do
  let(:compiler) { ThemeJavascriptCompiler.new(1, "marks", minify: false) }

  describe "connector module name handling" do
    it "separates colocated connectors to avoid module name clash" do
      # Colocated under `/connectors`
      compiler = ThemeJavascriptCompiler.new(1, "marks")
      compiler.append_tree(
        {
          "connectors/outlet/blah-1.hbs" => "{{var}}",
          "connectors/outlet/blah-1.js" => "console.log('test')",
        },
      )
      expect(compiler.content).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content).to include("discourse/theme-1/templates/connectors/outlet/blah-1")
      expect(JSON.parse(compiler.source_map)["sources"]).to contain_exactly(
        "connectors/outlet/blah-1.js",
        "templates/connectors/outlet/blah-1.js",
        "settings.js",
      )

      # Colocated under `/templates/connectors`
      compiler = ThemeJavascriptCompiler.new(1, "marks")
      compiler.append_tree(
        {
          "templates/connectors/outlet/blah-1.hbs" => "{{var}}",
          "templates/connectors/outlet/blah-1.js" => "console.log('test')",
        },
      )
      expect(compiler.content).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content).to include("discourse/theme-1/templates/connectors/outlet/blah-1")
      expect(JSON.parse(compiler.source_map)["sources"]).to contain_exactly(
        "connectors/outlet/blah-1.js",
        "templates/connectors/outlet/blah-1.js",
        "settings.js",
      )

      # Not colocated
      compiler = ThemeJavascriptCompiler.new(1, "marks")
      compiler.append_tree(
        {
          "templates/connectors/outlet/blah-1.hbs" => "{{var}}",
          "connectors/outlet/blah-1.js" => "console.log('test')",
        },
      )
      expect(compiler.content).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content).to include("discourse/theme-1/templates/connectors/outlet/blah-1")
      expect(JSON.parse(compiler.source_map)["sources"]).to contain_exactly(
        "connectors/outlet/blah-1.js",
        "templates/connectors/outlet/blah-1.js",
        "settings.js",
      )
    end
  end

  describe "error handling" do
    it "handles syntax errors in ember templates" do
      compiler.append_tree({ "sometemplate.hbs" => "{{invalidtemplate" })
      expect(compiler.content).to include('console.error("[THEME 1')
    end
  end

  describe "#append_tree" do
    it "can handle multiple modules" do
      compiler.append_tree(
        {
          "discourse/components/mycomponent.js" => <<~JS,
            import Component from "@glimmer/component";
            export default class MyComponent extends Component {}
          JS
          "discourse/templates/components/mycomponent.hbs" => "{{my-component-template}}",
        },
      )
      expect(compiler.content).to include(
        'define("discourse/theme-1/discourse/components/mycomponent"',
      )
      expect(compiler.content).to include(
        'define("discourse/theme-1/discourse/templates/components/mycomponent"',
      )
    end

    it "handles colocated components" do
      compiler.append_tree(
        {
          "discourse/components/mycomponent.js" => <<~JS,
            import Component from "@glimmer/component";
            export default class MyComponent extends Component {}
          JS
          "discourse/components/mycomponent.hbs" => "{{my-component-template}}",
        },
      )
      expect(compiler.content).to include("__COLOCATED_TEMPLATE__ =")
      expect(compiler.content).to include("setComponentTemplate")
    end

    it "handles colocated admin components" do
      compiler.append_tree(
        {
          "admin/components/mycomponent.js" => <<~JS,
            import Component from "@glimmer/component";
            export default class MyComponent extends Component {}
          JS
          "admin/components/mycomponent.hbs" => "{{my-component-template}}",
        },
      )
      expect(compiler.content).to include("__COLOCATED_TEMPLATE__ =")
      expect(compiler.content).to include("setComponentTemplate")
    end

    it "applies theme AST transforms to colocated components" do
      compiler = ThemeJavascriptCompiler.new(12_345_678_910, "my theme name")
      compiler.append_tree(
        { "discourse/components/mycomponent.hbs" => '{{theme-i18n "my_translation_key"}}' },
      )
      template_compiled_line = compiler.content.lines.find { |l| l.include?("block:") }
      expect(template_compiled_line).to include("12345678910")
    end

    it "prints error when default export missing" do
      compiler.append_tree(
        {
          "discourse/components/mycomponent.js" => <<~JS,
            import Component from "@glimmer/component";
            class MyComponent extends Component {}
          JS
          "discourse/components/mycomponent.hbs" => "{{my-component-template}}",
        },
      )
      expect(compiler.content).to include("__COLOCATED_TEMPLATE__ =")
      expect(compiler.content).to include("throw new Error")
    end

    it "handles template-only components" do
      compiler.append_tree(
        { "discourse/components/mycomponent.hbs" => "{{my-component-template}}" },
      )
      expect(compiler.content).to include("__COLOCATED_TEMPLATE__ =")
      expect(compiler.content).to include("setComponentTemplate")
      expect(compiler.content).to include("@ember/component/template-only")
    end
  end

  describe "terser compilation" do
    let(:compiler) { ThemeJavascriptCompiler.new(1, "marks", minify: true) }

    it "applies terser and provides sourcemaps" do
      sources = {
        "multiply.js" => "let multiply = (firstValue, secondValue) => firstValue * secondValue;",
        "add.js" => "let add = (firstValue, secondValue) => firstValue + secondValue;",
      }

      compiler.append_tree(sources)

      expect(compiler.content).to include("multiply")
      expect(compiler.content).to include("add")

      map = JSON.parse(compiler.source_map)
      expect(map["sources"]).to contain_exactly(*sources.keys, "settings.js")
      expect(map["sourcesContent"].to_s).to include("let multiply")
      expect(map["sourcesContent"].to_s).to include("let add")
      expect(map["sourceRoot"]).to eq("theme-1/")
    end

    it "handles invalid JS" do
      compiler.append_tree({ "filename.js" => "if(someCondition" })
      expect(compiler.content).to include("console.error('[THEME 1")
      expect(compiler.content).to include("Unexpected token")
    end
  end

  describe "ember-this-fallback" do
    it "applies its transforms" do
      compiler.append_tree(
        {
          "discourse/components/my-component.js" => <<~JS,
            import Component from "@glimmer/component";
            export default class MyComponent extends Component {
              value = "foo";
            }
          JS
          "discourse/components/my-component.hbs" => "{{value}}",
        },
      )
      expect(compiler.content).to include("ember-this-fallback")
      expect(compiler.content).to include(
        "The `value` property path was used in the `discourse/components/my-component.hbs` template without using `this`. This fallback behavior has been deprecated, all properties must be looked up on `this` when used in the template: {{this.value}}",
      )
    end
  end

  describe "ember-template-imports" do
    it "applies its transforms" do
      compiler.append_tree({ "discourse/components/my-component.gjs" => <<~JS })
        import Component from "@glimmer/component";

        export default class MyComponent extends Component {
          <template>
            {{this.value}}
          </template>

          value = "foo";
        }
      JS

      expect(compiler.content).to include(
        "define(\"discourse/theme-1/discourse/components/my-component\", [\"exports\",",
      )
      expect(compiler.content).to include('value = "foo";')
      expect(compiler.content).to include("setComponentTemplate")
      expect(compiler.content).to include("createTemplateFactory")
    end
  end

  describe "safari <16 class field bugfix" do
    it "is applied" do
      compiler.append_tree({ "discourse/components/my-component.js" => <<~JS })
        export default class MyComponent extends Component {
          value = "foo";
          complexValue = this.value + "bar";
        }
      JS

      expect(compiler.content).to include('value = "foo";')
      expect(compiler.content).to include('complexValue = (() => this.value + "bar")();')
    end
  end
end
