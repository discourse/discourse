# frozen_string_literal: true

require "stylesheet/importer"

RSpec.describe Stylesheet::Importer do
  def compile_css(name, options = {})
    Stylesheet::Compiler.compile_asset(name, options)[0]
  end

  describe "#font" do
    it "includes font variable" do
      default_font = ":root{--font-family: Inter, Arial, sans-serif}"
      expect(compile_css("color_definitions")).to include(default_font)
      expect(compile_css("embed")).to include(default_font)
      expect(compile_css("publish")).to include(default_font)
    end

    it "includes separate body and heading font declarations" do
      base_font = DiscourseFonts.fonts[2]
      heading_font = DiscourseFonts.fonts[3]

      SiteSetting.base_font = base_font[:key]
      SiteSetting.heading_font = heading_font[:key]

      expect(compile_css("color_definitions")).to include(
        ":root{--font-family: #{base_font[:stack]}}",
      ).and include(":root{--heading-font-family: #{heading_font[:stack]}}")

      set_cdn_url("http://cdn.localhost")

      # uses CDN and includes cache-breaking param
      expect(compile_css("color_definitions")).to include(
        "http://cdn.localhost/fonts/#{base_font[:variants][0][:filename]}?v=#{DiscourseFonts::VERSION}",
      ).and include(
              "http://cdn.localhost/fonts/#{heading_font[:variants][0][:filename]}?v=#{DiscourseFonts::VERSION}",
            )
    end

    it "includes all fonts in wizard" do
      expect(compile_css("wizard").scan(/\.body-font-/).count).to eq(DiscourseFonts.fonts.count)

      expect(compile_css("wizard").scan(/\.heading-font-/).count).to eq(DiscourseFonts.fonts.count)

      expect(compile_css("wizard").scan(/@font-face/).count).to eq(
        DiscourseFonts.fonts.map { |f| f[:variants]&.count || 0 }.sum,
      )
    end
  end

  describe "#import_color_definitions" do
    let(:scss) { ":root{--custom-color: green}" }
    let(:scss_child) do
      "$navy: #000080; :root{--custom-color: red; --custom-color-rgb: \#{hexToRGB($navy)}}"
    end

    let(:theme) do
      Fabricate(:theme).tap do |t|
        t.set_field(target: :common, name: "color_definitions", value: scss)
        t.save!
      end
    end

    let(:child) do
      Fabricate(:theme, component: true, name: "Child Theme").tap do |t|
        t.set_field(target: :common, name: "color_definitions", value: scss_child)
        t.save!
      end
    end

    it "should include color definitions in the theme" do
      styles = Stylesheet::Importer.new({ theme_id: theme.id }).import_color_definitions
      expect(styles).to include(scss)
    end

    it "should include color definitions from components" do
      theme.add_relative_theme!(:child, child)
      theme.save!

      styles = Stylesheet::Importer.new({ theme_id: theme.id }).import_color_definitions
      expect(styles).to include("Color definitions from Child Theme")
      expect(styles).to include("--custom-color: red")
      expect(styles).to include("--custom-color-rgb: 0, 0, 128")
    end

    it "should include default theme color definitions" do
      SiteSetting.default_theme_id = theme.id
      styles = Stylesheet::Importer.new({}).import_color_definitions
      expect(styles).to include(scss)
    end
  end

  describe "#import_wcag_overrides" do
    it "should do nothing on a regular scheme" do
      scheme = ColorScheme.create_from_base(name: "Regular")
      expect(Stylesheet::Importer.new({ color_scheme_id: scheme.id }).import_wcag_overrides).to eq(
        "",
      )
    end

    it "should include WCAG overrides for WCAG based scheme" do
      scheme = ColorScheme.create_from_base(name: "WCAG New", base_scheme_id: "WCAG Dark")
      expect(Stylesheet::Importer.new({ color_scheme_id: scheme.id }).import_wcag_overrides).to eq(
        "@import \"wcag\";",
      )
    end
  end
end
