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
    category = Fabricate(:category, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(#{background.url})}")

    GlobalSetting.stubs(:cdn_url).returns("//awesome.cdn")
    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(//awesome.cdn#{background.url})}")
  end

  it "applies S3 CDN to background category images" do
    SiteSetting.s3_use_iam_profile = true
    SiteSetting.s3_upload_bucket = 'test'
    SiteSetting.s3_region = 'ap-southeast-2'
    SiteSetting.s3_cdn_url = "https://s3.cdn"

    SiteSetting.enable_s3_uploads = true

    background = Fabricate(:upload_s3)
    category = Fabricate(:category, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(https://s3.cdn/original")
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

end
