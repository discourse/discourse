# frozen_string_literal: true

RSpec.describe ThemeJavascriptCompiler do
  let(:compiler) { ThemeJavascriptCompiler.new(1, "marks", minify: false) }

  describe "#append_ember_template" do
    it "maintains module names so that discourse-boot.js can correct them" do
      compiler.append_tree({ "connectors/blah-1.hbs" => "{{var}}" })
      compiler.append_tree({ "connectors/blah-2.hbs" => "{{var}}" })
      compiler.append_tree({ "javascripts/connectors/blah-3.hbs" => "{{var}}" })

      expect(compiler.content.to_s).to include(
        "themeCompatModules[\"templates/connectors/blah-1\"]",
      )
      expect(compiler.content.to_s).to include(
        "themeCompatModules[\"templates/connectors/blah-2\"]",
      )
      expect(compiler.content.to_s).to include(
        "themeCompatModules[\"javascripts/templates/connectors/blah-3\"]",
      )
    end
  end

  describe "connector module name handling" do
    it "separates colocated connectors to avoid module name clash" do
      # Colocated under `/connectors`
      compiler = ThemeJavascriptCompiler.new(1, "marks", minify: false)
      compiler.append_tree(
        {
          "connectors/outlet/blah-1.hbs" => "{{var}}",
          "connectors/outlet/blah-1.js" => "export default class MyComponent {};",
        },
      )
      expect(compiler.content.to_s).to include(
        'themeCompatModules["connectors/outlet/blah-1"]',
      ).once
      expect(compiler.content.to_s).to include("templates/connectors/outlet/blah-1")
      expect(compiler.content.to_s).not_to include("setComponentTemplate")
      expect(compiler.content.to_s).to include("createTemplateFactory")
      expect(JSON.parse(compiler.source_map)["sources"]).to include(
        "theme-1/connectors/outlet/blah-1.js",
        "theme-1/connectors/outlet/blah-1.hbs",
      )

      # Colocated under `/templates/connectors`
      compiler = ThemeJavascriptCompiler.new(1, "marks", minify: false)
      compiler.append_tree(
        {
          "templates/connectors/outlet/blah-1.hbs" => "{{var}}",
          "templates/connectors/outlet/blah-1.js" => "export default {};",
        },
      )
      expect(compiler.content.to_s).to include(
        'themeCompatModules["connectors/outlet/blah-1"]',
      ).once
      expect(compiler.content.to_s).to include("templates/connectors/outlet/blah-1")
      expect(compiler.content.to_s).not_to include("setComponentTemplate")
      expect(compiler.content.to_s).to include("createTemplateFactory")
      expect(JSON.parse(compiler.source_map)["sources"]).to include(
        "theme-1/templates/connectors/outlet/blah-1.js",
        "theme-1/templates/connectors/outlet/blah-1.hbs",
      )

      # Not colocated
      compiler = ThemeJavascriptCompiler.new(1, "marks", minify: false)
      compiler.append_tree(
        {
          "templates/connectors/outlet/blah-1.hbs" => "{{var}}",
          "connectors/outlet/blah-1.js" => "export default {};",
        },
      )
      expect(compiler.content.to_s).to include(
        'themeCompatModules["connectors/outlet/blah-1"]',
      ).once
      expect(compiler.content.to_s).to include("templates/connectors/outlet/blah-1")
      expect(compiler.content.to_s).not_to include("setComponentTemplate")
      expect(compiler.content.to_s).to include("createTemplateFactory")
      expect(JSON.parse(compiler.source_map)["sources"]).to include(
        "theme-1/connectors/outlet/blah-1.js",
        "theme-1/templates/connectors/outlet/blah-1.hbs",
      )

      # colocation in discourse directory
      compiler = ThemeJavascriptCompiler.new(1, "marks", minify: false)
      compiler.append_tree(
        {
          "discourse/connectors/outlet/blah-1.hbs" => "{{var}}",
          "discourse/connectors/outlet/blah-1.js" => "export default {};",
        },
      )
      expect(compiler.content.to_s).to include(
        'themeCompatModules["discourse/connectors/outlet/blah-1"]',
      ).once
      expect(compiler.content.to_s).to include("discourse/templates/connectors/outlet/blah-1")
      expect(compiler.content.to_s).not_to include("setComponentTemplate")
      expect(JSON.parse(compiler.source_map)["sources"]).to include(
        "theme-1/discourse/connectors/outlet/blah-1.js",
      )
    end
  end

  describe "error handling" do
    it "handles syntax errors in ember templates" do
      compiler.append_tree({ "sometemplate.hbs" => "{{invalidtemplate" })
      expect(compiler.content).to include("Parse error on line 1")
    end
  end

  describe "#append_tree" do
    it "can handle multiple modules" do
      compiler.append_tree(
        {
          "discourse/initializers/my-initializer.js" => <<~JS,
            import MyComponent from "../components/mycomponent";

            export default {
              name: "my-initializer",
              initialize() {
                console.log("my-initializer", MyComponent);
              },
            };
          JS
          "discourse/components/mycomponent.js" => <<~JS,
            import Component from "@glimmer/component";
            export default class MyComponent extends Component {}
          JS
          "discourse/templates/components/mycomponent.hbs" => "{{my-component-template}}",
        },
      )
      expect(compiler.content).to include('themeCompatModules["discourse/components/mycomponent"]')
      expect(compiler.content).to include(
        'themeCompatModules["discourse/templates/components/mycomponent"]',
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
      expect(compiler.content).to include("createTemplateFactory")
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
      compiler = ThemeJavascriptCompiler.new(12_345_678_910, "my theme name", minify: false)
      compiler.append_tree(
        { "discourse/components/mycomponent.hbs" => '{{theme-i18n "my_translation_key"}}' },
      )
      template_compiled_line = compiler.content.lines.find { |l| l.include?('"block":') }
      expect(template_compiled_line).to include("12345678910")
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
    let(:compiler) { ThemeJavascriptCompiler.new(1, "marks", {}, minify: true) }

    it "applies terser and provides sourcemaps" do
      sources = {
        "multiply.js" =>
          "export const multiply = (firstValue, secondValue) => firstValue * secondValue;",
        "add.js" => "export const add = (firstValue, secondValue) => firstValue + secondValue;",
      }

      compiler.append_tree(sources)

      expect(compiler.content).to include("multiply")
      expect(compiler.content).to include("add")
      expect(compiler.content).not_to include("firstValue")
      expect(compiler.content).not_to include("secondValue")

      map = JSON.parse(compiler.source_map)
      expect(map["sources"]).to include("theme-1/multiply.js", "theme-1/add.js")
      expect(map["sourcesContent"].to_s).to include("const multiply")
      expect(map["sourcesContent"].to_s).to include("const add")
      expect(map["sourcesContent"].to_s).to include("firstValue")
      expect(map["sourcesContent"].to_s).to include("secondValue")
    end

    it "handles invalid JS" do
      compiler.append_tree({ "filename.js" => "if(someCondition" })
      expect(compiler.content).to include('throw new Error("[THEME 1')
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
        "The `value` property path was used in the `theme-1/discourse/components/my-component.hbs` template without using `this`. This fallback behavior has been deprecated, all properties must be looked up on `this` when used in the template: {{this.value}}",
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
        "themeCompatModules[\"discourse/components/my-component\"]",
      )
      expect(compiler.content).to include('value = "foo";')
      expect(compiler.content).to include("setComponentTemplate")
      expect(compiler.content).to include("createTemplateFactory")
    end
  end
end
