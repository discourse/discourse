# frozen_string_literal: true

RSpec.describe ThemeJavascriptCompiler do
  let(:compiler) { ThemeJavascriptCompiler.new(1, 'marks') }

  describe "#append_raw_template" do
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
    it 'maintains module names so that discourse-boot.js can correct them' do
      compiler.append_ember_template("/connectors/blah-1", "{{var}}")
      expect(compiler.content.to_s).to include("define(\"discourse/theme-1/connectors/blah-1\", [\"exports\", \"@ember/template-factory\"]")

      compiler.append_ember_template("connectors/blah-2", "{{var}}")
      expect(compiler.content.to_s).to include("define(\"discourse/theme-1/connectors/blah-2\", [\"exports\", \"@ember/template-factory\"]")

      compiler.append_ember_template("javascripts/connectors/blah-3", "{{var}}")
      expect(compiler.content.to_s).to include("define(\"discourse/theme-1/javascripts/connectors/blah-3\", [\"exports\", \"@ember/template-factory\"]")
    end
  end

  describe "connector module name handling" do
    it 'separates colocated connectors to avoid module name clash' do
      # Colocated under `/connectors`
      compiler = ThemeJavascriptCompiler.new(1, 'marks')
      compiler.append_ember_template("connectors/outlet/blah-1", "{{var}}")
      compiler.append_module("console.log('test')", "connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/templates/connectors/outlet/blah-1")

      # Colocated under `/templates/connectors`
      compiler = ThemeJavascriptCompiler.new(1, 'marks')
      compiler.append_ember_template("templates/connectors/outlet/blah-1", "{{var}}")
      compiler.append_module("console.log('test')", "templates/connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/templates/connectors/outlet/blah-1")

      # Not colocated
      compiler = ThemeJavascriptCompiler.new(1, 'marks')
      compiler.append_ember_template("templates/connectors/outlet/blah-1", "{{var}}")
      compiler.append_module("console.log('test')", "connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/connectors/outlet/blah-1")
      expect(compiler.content.to_s).to include("discourse/theme-1/templates/connectors/outlet/blah-1")
    end
  end

  describe "error handling" do
    it "handles syntax errors in raw templates" do
      expect do
        compiler.append_raw_template("sometemplate.hbr", "{{invalidtemplate")
      end.to raise_error(ThemeJavascriptCompiler::CompileError, /Parse error on line 1/)
    end

    it "handles syntax errors in ember templates" do
      expect do
        compiler.append_ember_template("sometemplate", "{{invalidtemplate")
      end.to raise_error(ThemeJavascriptCompiler::CompileError, /Parse error on line 1/)
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
          "discourse/templates/components/mycomponent.hbs" => "{{my-component-template}}"
        }
      )
      expect(compiler.content).to include('define("discourse/theme-1/components/mycomponent"')
      expect(compiler.content).to include('define("discourse/theme-1/discourse/templates/components/mycomponent"')
    end
  end
end
