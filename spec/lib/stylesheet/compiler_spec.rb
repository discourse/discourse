# frozen_string_literal: true

require "stylesheet/compiler"

RSpec.describe Stylesheet::Compiler do
  describe "compilation" do
    Dir["#{Rails.root.join("app/assets/stylesheets")}/*.scss"].each do |path|
      next if path =~ /ember_cli/

      path = File.basename(path, ".scss")

      it "can compile '#{path}' css" do
        css, _map = Stylesheet::Compiler.compile_asset(path)
        expect(css.length).to be > 500
      end
    end
  end

  context "with a theme" do
    let!(:theme) { Fabricate(:theme) }
    let!(:upload) do
      UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(
        Discourse.system_user.id,
      )
    end
    let!(:upload_theme_field) do
      ThemeField.create!(
        theme: theme,
        target_id: 0,
        name: "primary",
        upload: upload,
        value: "",
        type_id: ThemeField.types[:theme_upload_var],
      )
    end
    let!(:stylesheet_theme_field) do
      ThemeField.create!(
        theme: theme,
        target_id: 0,
        name: "scss",
        value: "body { background: $primary }",
        type_id: ThemeField.types[:scss],
      )
    end

    it "theme stylesheet should be able to access theme asset variables" do
      theme.reload.with_scss_load_paths do |load_paths|
        css, _map =
          Stylesheet::Compiler.compile_asset(
            "common_theme",
            theme_id: theme.id,
            theme_variables: theme.scss_variables,
            load_paths: load_paths,
          )
        expect(css).to include(upload.url)
      end
    end

    context "with a plugin" do
      let :plugin1 do
        plugin1 = plugin_from_fixtures("my_plugin")
        plugin1.register_css "body { background: $primary }"
        plugin1
      end

      let :plugin2 do
        plugin2 = plugin_from_fixtures("scss_plugin")
        plugin2
      end

      before do
        Discourse.plugins << plugin1
        Discourse.plugins << plugin2
        plugin1.activate!
        plugin2.activate!
        Stylesheet::Importer.register_imports!
      end

      after do
        Discourse.plugins.delete plugin1
        Discourse.plugins.delete plugin2
        Stylesheet::Importer.register_imports!
        DiscoursePluginRegistry.reset!
      end

      it "does not include theme variables in plugins" do
        css, _map = Stylesheet::Compiler.compile_asset("my_plugin", theme_id: theme.id)
        expect(css).not_to include(upload.url)
        expect(css).to include("background:")
      end

      context "with the `rtl` option" do
        it "generates an RTL version of the plugin CSS if the option is true" do
          css, _ = Stylesheet::Compiler.compile_asset("scss_plugin", theme_id: theme.id, rtl: true)
          expect(css).to include(".pull-left{float:right}")
          expect(css).not_to include(".pull-left{float:left}")
        end

        it "returns an unchanged version of the plugin CSS" do
          css, _ = Stylesheet::Compiler.compile_asset("scss_plugin", theme_id: theme.id, rtl: false)
          expect(css).to include(".pull-left{float:left}")
          expect(css).not_to include(".pull-left{float:right}")
        end
      end

      it "supports SCSS imports" do
        css, _map = Stylesheet::Compiler.compile_asset("scss_plugin", theme_id: theme.id)

        expect(css).to include("border-color:red")
        expect(css).to include("fill:green")
        expect(css).to include("line-height:1.2em")
        expect(css).to include("border-color:#c00")
        expect(css).to include("--simple-css-color: red")
      end
    end
  end

  it "supports absolute-image-url" do
    scss = Stylesheet::Importer.new({}).prepended_scss
    scss += ".body{background-image: absolute-image-url('/favicons/github.png');}"
    css, _map = Stylesheet::Compiler.compile(scss, "test.scss")

    expect(css).to include('url("http://test.localhost/images/favicons/github.png")')
    expect(css).not_to include("absolute-image-url")
  end

  it "supports absolute-image-url in subfolder" do
    set_subfolder "/subfo"
    scss = Stylesheet::Importer.new({}).prepended_scss
    scss += ".body{background-image: absolute-image-url('/favicons/github.png');}"
    css, _map = Stylesheet::Compiler.compile(scss, "test2.scss")

    expect(css).to include('url("http://test.localhost/subfo/images/favicons/github.png")')
    expect(css).not_to include("absolute-image-url")
  end

  it "supports absolute-image-url with CDNs" do
    set_cdn_url "https://awesome.com"
    scss = Stylesheet::Importer.new({}).prepended_scss
    scss += ".body{background-image: absolute-image-url('/favicons/github.png');}"
    css, _map = Stylesheet::Compiler.compile(scss, "test2.scss")

    expect(css).to include('url("https://awesome.com/images/favicons/github.png")')
    expect(css).not_to include("absolute-image-url")
  end

  it "supports absolute-image-url in plugins" do
    set_cdn_url "https://awesome.com"
    scss = Stylesheet::Importer.new({}).prepended_scss
    scss +=
      ".body{background-image: absolute-image-url('/plugins/discourse-special/images/somefile.png');}"
    css, _map = Stylesheet::Compiler.compile(scss, "discourse-special.scss")

    expect(css).to include(
      'url("https://awesome.com/plugins/discourse-special/images/somefile.png")',
    )
    expect(css).not_to include("absolute-image-url")
  end

  context "with a color scheme" do
    it "returns the default color definitions when no color scheme is specified" do
      css, _map = Stylesheet::Compiler.compile_asset("color_definitions")
      expect(css).to include("--header_background:")
      expect(css).to include("--primary:")
    end

    it "returns color definitions for a custom color scheme" do
      cs =
        Fabricate(
          :color_scheme,
          name: "Stylish",
          color_scheme_colors: [
            Fabricate(:color_scheme_color, name: "header_primary", hex: "88af8e"),
            Fabricate(:color_scheme_color, name: "header_background", hex: "f8745c"),
          ],
        )

      css, _map = Stylesheet::Compiler.compile_asset("color_definitions", color_scheme_id: cs.id)

      expect(css).to include("--header_background: #f8745c")
      expect(css).to include("--header_primary: #88af8e")
      expect(css).to include("--header_background-rgb: 248, 116, 92")
    end

    context "with a plugin" do
      before do
        plugin = plugin_from_fixtures("color_definition")
        Discourse.plugins << plugin
        plugin.activate!
      end

      after do
        Discourse.plugins.pop
        DiscoursePluginRegistry.reset!
      end

      it "includes color definitions from plugins" do
        css, _map = Stylesheet::Compiler.compile_asset("color_definitions")

        expect(css).to include("--plugin-color")
      end
    end
  end

  describe "indexes" do
    it "include all SCSS files in their respective folders" do
      refs = []

      Dir
        .glob(Rails.root.join("app/assets/stylesheets/**/*/"))
        .each do |dir|
          Dir
            .glob("#{dir}_index.scss")
            .each do |indexfile|
              contents = File.read indexfile

              files = Dir["#{dir}*.scss"]
              files -= Dir["#{dir}_index.scss"]
              files.each do |path|
                filename = File.basename(path, ".scss")
                if !contents.match(/@import "#{filename}";/)
                  refs << "#{filename} import missing in #{indexfile}"
                end
              end
            end
        end

      expect(refs).to eq([])
    end
  end

  describe ".compile" do
    it "produces RTL CSS when rtl option is given" do
      css, _ = Stylesheet::Compiler.compile("a{right:1px}", "test.scss", rtl: true)
      expect(css).to eq("a{left:1px}")
    end

    it "runs through postcss" do
      css, map = Stylesheet::Compiler.compile(<<~SCSS, "test.scss")
        @media (min-resolution: 2dppx) {
          body {
            background-color: light-dark(white, black);
          }
        }
      SCSS

      expect(css).to include("csstools-light-dark-toggle")
      expect(css).not_to include("& * {") # No native nesting
      expect(map.size).to be > 10
    end

    it "handles errors gracefully" do
      bad_css = <<~SCSS
        $foo: unquote("https://notacolor.example.com");
        .example {
          color: $foo;
        }
      SCSS

      expect { Stylesheet::Compiler.compile(bad_css, "test.scss") }.to raise_error(
        AssetProcessor::TranspileError,
        /Missed semicolon/,
      )
    end
  end
end
