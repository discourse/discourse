# frozen_string_literal: true

require 'rails_helper'
require 'stylesheet/compiler'

describe Stylesheet::Compiler do
  describe 'compilation' do
    Dir["#{Rails.root.join("app/assets/stylesheets")}/*.scss"].each do |path|
      path = File.basename(path, '.scss')

      it "can compile '#{path}' css" do
        css, _map = Stylesheet::Compiler.compile_asset(path)
        expect(css.length).to be > 1000
      end
    end
  end

  context "with a theme" do
    let!(:theme) { Fabricate(:theme) }
    let!(:upload) { Fabricate(:upload) }
    let!(:upload_theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "primary", upload: upload, value: "", type_id: ThemeField.types[:theme_upload_var]) }
    let!(:stylesheet_theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "scss", value: "body { background: $primary }", type_id: ThemeField.types[:scss]) }
    before { stylesheet_theme_field.save! }

    it "theme stylesheet should be able to access theme asset variables" do
      css, _map = Stylesheet::Compiler.compile_asset("desktop_theme", theme_id: theme.id)
      expect(css).to include(upload.url)
    end

    context "with a plugin" do
      before do
        plugin = Plugin::Instance.new
        plugin.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
        plugin.register_css "body { background: $primary }"
        Discourse.plugins << plugin
        plugin.activate!
        Stylesheet::Importer.register_imports!
      end

      after do
        Discourse.plugins.pop
        Stylesheet::Importer.register_imports!
        DiscoursePluginRegistry.reset!
      end

      it "does not include theme variables in plugins" do
        css, _map = Stylesheet::Compiler.compile_asset("my_plugin", theme_id: theme.id)
        expect(css).not_to include(upload.url)
        expect(css).to include("background:")
      end
    end
  end

  it "supports asset-url" do
    css, _map = Stylesheet::Compiler.compile(".body{background-image: asset-url('/images/favicons/github.png');}", "test.scss")

    expect(css).to include("url('/images/favicons/github.png')")
    expect(css).not_to include('asset-url')
  end

  it "supports image-url" do
    css, _map = Stylesheet::Compiler.compile(".body{background-image: image-url('/favicons/github.png');}", "test.scss")

    expect(css).to include("url('/favicons/github.png')")
    expect(css).not_to include('image-url')
  end
end
