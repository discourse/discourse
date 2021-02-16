# frozen_string_literal: true

require 'rails_helper'
require 'stylesheet/importer'

describe Stylesheet::Importer do

  def compile_css(name)
    Stylesheet::Compiler.compile_asset(name)[0]
  end

  it "applies CDN to background category images" do
    expect(compile_css("category_backgrounds")).to_not include("background-image")

    background = Fabricate(:upload)
    parent_category = Fabricate(:category)
    category = Fabricate(:category, parent_category_id: parent_category.id, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{parent_category.slug}-#{category.slug}{background-image:url(#{background.url})}")

    GlobalSetting.stubs(:cdn_url).returns("//awesome.cdn")
    expect(compile_css("category_backgrounds")).to include("body.category-#{parent_category.slug}-#{category.slug}{background-image:url(//awesome.cdn#{background.url})}")
  end

  it "applies S3 CDN to background category images" do
    setup_s3
    SiteSetting.s3_use_iam_profile = true
    SiteSetting.s3_upload_bucket = 'test'
    SiteSetting.s3_region = 'ap-southeast-2'
    SiteSetting.s3_cdn_url = "https://s3.cdn"

    background = Fabricate(:upload_s3)
    category = Fabricate(:category, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{category.slug}{background-image:url(https://s3.cdn/original")
  end

  it "includes font variable" do
    expect(compile_css("desktop"))
      .to include(":root{--font-family: Arial, sans-serif}")
  end

  it "includes separate body and heading font declarations" do
    base_font = DiscourseFonts.fonts[2]
    heading_font = DiscourseFonts.fonts[3]

    SiteSetting.base_font = base_font[:key]
    SiteSetting.heading_font = heading_font[:key]

    expect(compile_css("desktop"))
      .to include(":root{--font-family: #{base_font[:stack]}}")
      .and include(":root{--heading-font-family: #{heading_font[:stack]}}")
  end

  it "includes all fonts in wizard" do
    expect(compile_css("wizard").scan(/\.body-font-/).count)
      .to eq(DiscourseFonts.fonts.count)

    expect(compile_css("wizard").scan(/\.heading-font-/).count)
      .to eq(DiscourseFonts.fonts.count)

    expect(compile_css("wizard").scan(/@font-face/).count)
      .to eq(DiscourseFonts.fonts.map { |f| f[:variants]&.count || 0 }.sum)
  end

  context "#import_color_definitions" do
    let(:scss) { ":root{--custom-color: green}" }
    let(:scss_child) { ":root{--custom-color: red}" }

    let(:theme) do
      Fabricate(:theme).tap do |t|
        t.set_field(target: :common, name: "color_definitions", value: scss)
        t.save!
      end
    end

    let(:child) { Fabricate(:theme, component: true, name: "Child Theme").tap { |t|
      t.set_field(target: :common, name: "color_definitions", value: scss_child)
      t.save!
    }}

    it "should include color definitions in the theme" do
      styles = Stylesheet::Importer.import_color_definitions(theme.id)
      expect(styles).to include(scss)
    end

    it "should include color definitions from components" do
      theme.add_relative_theme!(:child, child)
      theme.save!

      styles = Stylesheet::Importer.import_color_definitions(theme.id)
      expect(styles).to include(scss_child)
      expect(styles).to include("Color definitions from Child Theme")
    end

    it "should include default theme color definitions" do
      SiteSetting.default_theme_id = theme.id
      styles = Stylesheet::Importer.import_color_definitions(nil)
      expect(styles).to include(scss)
    end
  end

  context "#import_wcag_overrides" do
    it "should do nothing on a regular scheme" do
      scheme = ColorScheme.create_from_base(name: 'Regular')
      expect(Stylesheet::Importer.import_wcag_overrides(scheme.id)).to eq("")
    end

    it "should include WCAG overrides for WCAG based scheme" do
      scheme = ColorScheme.create_from_base(name: 'WCAG New', base_scheme_id: "WCAG Dark")
      expect(Stylesheet::Importer.import_wcag_overrides(scheme.id)).to eq("@import \"wcag\";")
    end
  end
end
