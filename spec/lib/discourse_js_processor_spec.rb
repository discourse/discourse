# frozen_string_literal: true

require 'discourse_js_processor'

RSpec.describe DiscourseJsProcessor do

  describe 'should_transpile?' do
    it "returns false for empty strings" do
      expect(DiscourseJsProcessor.should_transpile?(nil)).to eq(false)
      expect(DiscourseJsProcessor.should_transpile?('')).to eq(false)
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
      expect(DiscourseJsProcessor.skip_module?('')).to eq(false)
    end

    it "returns true if the header is present" do
      expect(DiscourseJsProcessor.skip_module?("// cool comment\n// discourse-skip-module")).to eq(true)
    end

    it "returns false if the header is not present" do
      expect(DiscourseJsProcessor.skip_module?("// just some JS\nconsole.log()")).to eq(false)
    end
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
          "block": "[[[1,[34,0]]],[],false,[\\"somevalue\\"]]",
          "moduleName": "(unknown template module)",
          "isStrictMode": false
        });
      });
    JS
  end
end
