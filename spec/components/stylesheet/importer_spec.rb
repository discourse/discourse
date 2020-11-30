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
      .to include(":root{--font-family: Helvetica, Arial, sans-serif}")
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

  context "#theme_variables" do

    let!(:theme) { Fabricate(:theme) }

    let(:importer) { described_class.new(theme: theme) }

    fab!(:upload) { Fabricate(:upload) }
    fab!(:upload_s3) { Fabricate(:upload_s3) }

    let!(:theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "var", upload: upload, value: "", type_id: ThemeField.types[:theme_upload_var]) }
    let!(:theme_field_s3) { ThemeField.create!(theme: theme, target_id: 1, name: "var_s3", upload: upload_s3, value: "", type_id: ThemeField.types[:theme_upload_var]) }

    it "should contain the URL" do
      theme_field.save!
      import = importer.imports("theme_variables", nil)
      expect(import.source).to include(upload.url)
    end

    it "should contain the S3 URL" do
      theme_field_s3.save!
      import = importer.imports("theme_variables", nil)
      expect(import.source).to include(upload_s3.url)
    end

  end

  context "extra_scss" do
    let(:scss) { "body { background: red}" }
    let(:child_scss) { "body { background: green}" }

    let(:theme) { Fabricate(:theme).tap { |t|
      t.set_field(target: :extra_scss, name: "my_files/magic", value: scss)
      t.save!
    }}

    let(:child_theme) { Fabricate(:theme).tap { |t|
      t.component = true
      t.set_field(target: :extra_scss, name: "my_files/moremagic", value: child_scss)
      t.save!
      theme.add_relative_theme!(:child, t)
    }}

    let(:importer) { described_class.new(theme: theme) }

    it "should be able to import correctly" do
      # Import from regular theme file
      expect(
        importer.imports(
          "my_files/magic",
          "theme_#{theme.id}/desktop-scss-mytheme.scss"
        ).source).to eq(scss)

      # Import from some deep file
      expect(
        importer.imports(
          "my_files/magic",
          "theme_#{theme.id}/some/deep/folder/structure/myfile.scss"
        ).source).to eq(scss)

      # Import from parent dir
      expect(
        importer.imports(
          "../../my_files/magic",
          "theme_#{theme.id}/my_files/folder1/myfile.scss"
        ).source).to eq(scss)

      # Import from same dir without ./
      expect(
        importer.imports(
          "magic",
          "theme_#{theme.id}/my_files/myfile.scss"
        ).source).to eq(scss)

      # Import from same dir with ./
      expect(
        importer.imports(
          "./magic",
          "theme_#{theme.id}/my_files/myfile.scss"
        ).source).to eq(scss)

      # Import within a child theme
      expect(
        importer.imports(
          "my_files/moremagic",
          "theme_#{child_theme.id}/theme_field.scss"
        ).source).to eq(child_scss)
    end

  end

  context "#import_color_definitions" do
    let(:scss) { ":root { --custom-color: green}" }
    let(:scss_child) { ":root { --custom-color: red}" }

    let(:theme) do
      Fabricate(:theme).tap do |t|
        t.set_field(target: :common, name: "color_definitions", value: scss)
        t.save!
      end
    end

    let(:child) { Fabricate(:theme, component: true).tap { |t|
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
