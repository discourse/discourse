# frozen_string_literal: true

RSpec.describe AssetProcessor do
  def entrypoint(result, name)
    result.values.find { |chunk| chunk["name"] == name }
  end

  describe "skip_module?" do
    it "returns false for empty strings" do
      expect(AssetProcessor.skip_module?(nil)).to eq(false)
      expect(AssetProcessor.skip_module?("")).to eq(false)
    end

    it "returns true if the header is present" do
      expect(AssetProcessor.skip_module?("// cool comment\n// discourse-skip-module")).to eq(true)
    end

    it "returns false if the header is not present" do
      expect(AssetProcessor.skip_module?("// just some JS\nconsole.log()")).to eq(false)
    end

    it "works end-to-end" do
      source = <<~JS.chomp
        // discourse-skip-module
        console.log("hello world");
      JS
      expect(AssetProcessor.transpile(source, "test", "test")).to eq(source)
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

    result = AssetProcessor.transpile(script, "blah", "blah/mymodule")
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

    result = AssetProcessor.transpile(script, "blah", "blah/mymodule")
    expect(result).to include("dt7948.n(")
  end

  it "hashes every file outside the asset processor that it imports" do
    # The processor is cached under a digest of its inputs, so anything it reaches
    # outside its own directory has to be listed or its changes go unnoticed.
    processor_dir = File.expand_path("frontend/asset-processor")
    hashed =
      AssetProcessor::BUNDLE
        .dependency_globs
        .flat_map { |glob| Dir.glob(glob) }
        .map { |path| File.expand_path(path) }
        .to_set

    resolve_import = ->(specifier, from) do
      base = File.expand_path(specifier, File.dirname(from))
      candidates = [base] + %w[.js .mjs].flat_map { |ext| ["#{base}#{ext}", "#{base}/index#{ext}"] }
      candidates.find { |candidate| File.file?(candidate) }
    end

    queue =
      Dir
        .glob("frontend/asset-processor/**/*.{js,mjs}")
        .reject { |path| path.end_with?(".test.mjs") || path.include?("/node_modules/") }
        .map { |path| File.expand_path(path) }
    seen = queue.to_set
    external = {}

    until queue.empty?
      importer = queue.shift

      File
        .read(importer)
        .scan(/(?:from|import|require)\s*\(?\s*["']([^"']+)["']/)
        .flatten
        .select { |specifier| specifier.start_with?(".") }
        .each do |specifier|
          resolved = resolve_import.call(specifier, importer)
          next if resolved.nil? || resolved.include?("/node_modules/") || seen.include?(resolved)

          seen << resolved
          # Reachable core files are themselves scanned, so a transitive import
          # cannot slip past the digest either.
          external[resolved] = importer unless resolved.start_with?("#{processor_dir}/")
          queue << resolved
        end
    end

    expect(external).not_to be_empty

    aggregate_failures do
      external.each do |path, imported_by|
        expect(hashed).to include(path),
        "#{Pathname.new(path).relative_path_from(Rails.root)} is imported by " \
          "#{Pathname.new(imported_by).relative_path_from(Rails.root)} " \
          "but is not in AssetProcessor::BUNDLE's dependency_globs"
      end
    end
  end

  describe "Transpiler#terser" do
    it "can minify code and provide sourcemaps" do
      sources = {
        "multiply.js" => "let multiply = (firstValue, secondValue) => firstValue * secondValue;",
        "add.js" => "let add = (firstValue, secondValue) => firstValue + secondValue;",
      }

      result = AssetProcessor.new.terser(sources, { sourceMap: { includeSources: true } })
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
              console.log("hello world");
            }
            <template>
              <div>template content</div>
            </template>
          }
        JS

      result =
        AssetProcessor.new.rollup(
          sources,
          { entrypoints: { main: { modules: ["discourse/initializers/hello.gjs"] } } },
        )

      code = entrypoint(result, "main")["code"]
      expect(code).to include('"hello world"')
      expect(code).to include("dt7948") # Decorator transform

      expect(entrypoint(result, "main")["map"]).not_to be_nil
    end

    it "can import module source" do
      example = <<~GJS
        const label = "Save";

        export default <template>
          <button type="button">{{label}}</button>
        </template>;
      GJS

      sources = {
        "discourse/components/example.gjs" => example,
        "discourse/lib/plain.js" => "export const MAX_LENGTH = 50;\n",
        "discourse/initializers/example-source.js" => <<~JS,
          import whole from "../components/example.gjs?source=file";
          import template from "../components/example.gjs?source=template";
          import extensionless from "../components/example?source=template";
          import templateless from "../lib/plain.js?source=file";

          globalThis.whole = whole;
          globalThis.template = template;
          globalThis.extensionless = extensionless;
          globalThis.templateless = templateless;
        JS
      }

      result =
        AssetProcessor.new.rollup(
          sources,
          { entrypoints: { main: { modules: ["discourse/initializers/example-source.js"] } } },
        )

      context = MiniRacer::Context.new
      code = entrypoint(result, "main")["code"].sub(/export \{.*\};\s*\z/, "")
      context.eval(code)

      aggregate_failures do
        expect(context.eval("globalThis.whole")).to eq(example.strip)
        expect(context.eval("globalThis.template")).to eq(
          '<button type="button">{{label}}</button>',
        )
        expect(context.eval("globalThis.extensionless")).to eq(
          '<button type="button">{{label}}</button>',
        )
        expect(context.eval("globalThis.templateless")).to eq("export const MAX_LENGTH = 50;")
      end
    ensure
      context&.dispose
    end

    it "can import the source of a template-only module" do
      sources = {
        "discourse/components/tmpl.hbs" => "<div>Hello {{name}}</div>",
        "discourse/initializers/example-source.js" => <<~JS,
          import exampleSource from "../components/tmpl.hbs?source=file";

          globalThis.exampleSource = exampleSource;
        JS
      }

      result =
        AssetProcessor.new.rollup(
          sources,
          { entrypoints: { main: { modules: ["discourse/initializers/example-source.js"] } } },
        )

      context = MiniRacer::Context.new
      code = entrypoint(result, "main")["code"].sub(/export \{.*\};\s*\z/, "")
      context.eval(code)

      expect(context.eval("globalThis.exampleSource")).to eq("<div>Hello {{name}}</div>")
    ensure
      context&.dispose
    end

    it "rejects source imports it cannot read" do
      # `discourse-colocation` resolves a .js id for a component that only exists as a
      # colocated .hbs, so this reaches the source plugin with nothing behind it.
      sources = {
        "discourse/components/colocated.hbs" => "<div>Example</div>",
        "discourse/initializers/example-source.js" => <<~JS,
          import exampleSource from "../components/colocated.js?source=file";

          globalThis.exampleSource = exampleSource;
        JS
      }

      expect do
        AssetProcessor.new.rollup(
          sources,
          { entrypoints: { main: { modules: ["discourse/initializers/example-source.js"] } } },
        )
      end.to raise_error(AssetProcessor::TranspileError, /ENOENT/)
    end

    it "rejects source imports from outside the bundle" do
      sources = { "discourse/initializers/example-source.js" => <<~JS }
          import exampleSource from "discourse/components/external.gjs?source=file";

          globalThis.exampleSource = exampleSource;
        JS

      expect do
        AssetProcessor.new.rollup(
          sources,
          { entrypoints: { main: { modules: ["discourse/initializers/example-source.js"] } } },
        )
      end.to raise_error(AssetProcessor::TranspileError, /Cannot import source from/)
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
        AssetProcessor.new.rollup(
          { "discourse/initializers/foo.js" => script },
          { entrypoints: { main: { modules: ["discourse/initializers/foo.js"] } } },
        )
      expect(entrypoint(result, "main")["code"]).to include("dt7948.n")
    end

    it "supports object literal decorators without errors" do
      script = <<~JS.chomp
        export default {
          @decorated foo: "bar",

          @decorated
          myMethod() {
            console.log("hello world");
          }
        }
      JS

      result =
        AssetProcessor.new.rollup(
          { "discourse/initializers/foo.js" => script },
          { entrypoints: { main: { modules: ["discourse/initializers/foo.js"] } } },
        )
      expect(entrypoint(result, "main")["code"]).to include("dt7948")
    end

    it "can use themePrefix in a template" do
      script = <<~JS.chomp
        themePrefix();
        export default class Foo {
          <template>{{themePrefix "bar"}}</template>
        }
      JS

      result =
        AssetProcessor.new.rollup(
          { "discourse/initializers/foo.gjs" => script },
          { themeId: 22, entrypoints: { main: { modules: ["discourse/initializers/foo.gjs"] } } },
        )
      expect(entrypoint(result, "main")["code"]).to include(
        'window.moduleBroker.lookup("discourse/lib/theme-settings-store")',
      )
    end

    it "strips data-test-* attributes in production mode" do
      script = <<~JS.chomp
        export default class Foo {
          <template>
            <div data-test-my-element class="keep">hello</div>
          </template>
        }
      JS

      modules = { "discourse/components/foo.gjs" => script }
      entrypoints = { main: { modules: ["discourse/components/foo.gjs"] } }

      unminified = AssetProcessor.new.rollup(modules, { themeId: 22, entrypoints: entrypoints })
      expect(entrypoint(unminified, "main")["code"]).to include("data-test-my-element")

      minified =
        AssetProcessor.new.rollup(modules, { minify: true, themeId: 22, entrypoints: entrypoints })
      code = entrypoint(minified, "main")["code"]
      expect(code).not_to include("data-test-my-element")
      expect(code).to include("keep")
    end

    it "preserves optionality of cross-plugin imports" do
      script = <<~JS.chomp
        import Example from "discourse/plugins/styleguide/discourse/components/example" with { discourseImport: "optional" };
        console.log(Example);
      JS

      result =
        AssetProcessor.new.rollup(
          { "discourse/components/foo.js" => script },
          {
            pluginName: "chat",
            entrypoints: {
              main: {
                modules: ["discourse/components/foo.js"],
              },
            },
          },
        )

      code = entrypoint(result, "main")["code"]
      expect(code).to include('"discourse/plugins/styleguide?"')
      expect(code).not_to include('"discourse/plugins/styleguide"')
    end

    it "can use themePrefix not in a template" do
      script = <<~JS.chomp
        export default function foo() {
          return themePrefix("bar");
        }
      JS

      result =
        AssetProcessor.new.rollup(
          { "discourse/initializers/foo.js" => script },
          { themeId: 22, entrypoints: { main: { modules: ["discourse/initializers/foo.js"] } } },
        )
      expect(entrypoint(result, "main")["code"]).to include(
        'window.moduleBroker.lookup("discourse/lib/theme-settings-store")',
      )
    end
  end

  it "can compile hbs" do
    template = <<~HBS.chomp
      {{log "hello world"}}
    HBS

    result =
      AssetProcessor.new.rollup(
        { "discourse/connectors/outlet-name/foo.hbs" => template },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: ["discourse/connectors/outlet-name/foo.hbs"],
            },
          },
        },
      )
    code = entrypoint(result, "main")["code"]
    expect(code).to include("createTemplateFactory")
    expect(code).to include("deprecated(")
    expect(code).to include('id: "discourse.hbs-extension"')
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
      AssetProcessor.new.rollup(
        {
          "discourse/components/foo.js" => js,
          "discourse/components/foo.hbs" => template,
          "discourse/components/bar.hbs" => onlyTemplate,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[discourse/components/foo.js discourse/components/bar.hbs],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).to include("setComponentTemplate")
    expect(entrypoint(result, "main")["code"]).to include(
      "bar = setComponentTemplate(__COLOCATED_TEMPLATE__, templateOnly());",
    )
  end

  it "handles colocation of connectors" do
    js = <<~JS.chomp
      export default {
        setupComponent(args, component) {
          console.log("hello world");
        }
      }
    JS

    template = <<~HBS.chomp
      {{log "hello world"}}
    HBS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/templates/connectors/foo.js" => js,
          "discourse/templates/connectors/foo.hbs" => template,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[
                discourse/templates/connectors/foo.js
                discourse/templates/connectors/foo.hbs
              ],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).to include(
      '"discourse/templates/connectors/foo":',
    ).once
    expect(entrypoint(result, "main")["code"]).to include('"discourse/connectors/foo":').once
  end

  it "handles relative imports from one module to another" do
    mod_1 = <<~JS.chomp
      export default "test";
    JS

    mod_2 = <<~JS.chomp
      import MyComponent from "../components/my-component";
      console.log(MyComponent);
    JS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/components/my-component.js" => mod_1,
          "discourse/components/other-component.js" => mod_2,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: ["discourse/components/other-component.js"],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).not_to include("../components/my-component")
  end

  it "handles relative import of index file" do
    mod_1 = <<~JS.chomp
      import MyComponent from "./other-component";
      console.log(MyComponent);
    JS

    mod_2 = <<~JS.chomp
      export default "test";
    JS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/components/my-component.js" => mod_1,
          "discourse/components/other-component/index.js" => mod_2,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[
                discourse/components/my-component.js
                discourse/components/other-component/index.js
              ],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).not_to include("../components/my-component")
  end

  it "handles relative import of gjs index file" do
    mod_1 = <<~JS.chomp
      import MyComponent from "./other-component";
      console.log(MyComponent);
    JS

    mod_2 = <<~JS.chomp
      export default "test";
    JS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/components/my-component.gjs" => mod_1,
          "discourse/components/other-component/index.gjs" => mod_2,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[
                discourse/components/my-component.gjs
                discourse/components/other-component/index.gjs
              ],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).not_to include("../components/my-component")
  end

  it "prioritizes exact match over /index match" do
    mod_1 = <<~JS.chomp
      export default "module 1";
    JS

    mod_2 = <<~JS.chomp
      export default "module 2";
    JS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/components/my-component.gjs" => mod_1,
          "discourse/components/my-component/index.gjs" => mod_2,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[
                discourse/components/my-component/index.gjs
                discourse/components/my-component.gjs
              ],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["code"]).to include("module 1")
    expect(entrypoint(result, "main")["code"]).to include("module 2")
  end

  it "returns the ember version" do
    expect(AssetProcessor.ember_version).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "errors on missing relative imports for plugin names without hyphens" do
    mod_1 = <<~JS.chomp
      import SomeModule from "../some-module";
      console.log(SomeModule);
    JS

    expect do
      AssetProcessor.new.rollup(
        { "discourse/components/my-component.gjs" => mod_1 },
        { pluginName: "myplugin" },
      )
    end.to raise_error(AssetProcessor::TranspileError)
  end

  it "outputs entrypoint manifest data" do
    mod = <<~JS.chomp
      export default "module 1";
    JS

    admin_mod = <<~JS.chomp
      import comp from "./my-component";
      console.log(comp);
      export default "module 2";
    JS

    result =
      AssetProcessor.new.rollup(
        {
          "discourse/components/my-component.gjs" => mod,
          "discourse/components/my-admin-component.gjs" => admin_mod,
        },
        {
          themeId: 22,
          entrypoints: {
            main: {
              modules: %w[discourse/components/my-component.gjs],
            },
            admin: {
              modules: %w[discourse/components/my-admin-component.gjs],
            },
          },
        },
      )

    expect(entrypoint(result, "main")["imports"].length).to eq(1)
    expect(entrypoint(result, "main")["imports"].first).to include("chunk")
    expect(entrypoint(result, "main")["name"]).to eq("main")
    expect(entrypoint(result, "main")["isEntry"]).to eq(true)

    expect(entrypoint(result, "admin")["imports"].length).to eq(1)
    expect(entrypoint(result, "admin")["imports"].first).to include("chunk")
    expect(entrypoint(result, "admin")["name"]).to eq("admin")
    expect(entrypoint(result, "admin")["isEntry"]).to eq(true)
  end

  it "errors on missing relative imports for plugin names with hyphens" do
    mod_1 = <<~JS.chomp
      import SomeModule from "../some-module";
      console.log(SomeModule);
    JS

    expect do
      AssetProcessor.new.rollup(
        { "discourse/components/my-component.gjs" => mod_1 },
        { pluginName: "my-plugin" },
      )
    end.to raise_error(AssetProcessor::TranspileError)
  end
end
