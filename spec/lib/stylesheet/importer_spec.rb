# frozen_string_literal: true

require "stylesheet/importer"

RSpec.describe Stylesheet::Importer do
  def compile_css(name, options = {})
    Stylesheet::Compiler.compile_asset(name, options)[0]
  end

  describe "#category_backgrounds" do
    it "uses the correct background image based in the color scheme" do
      background = Fabricate(:upload)
      background_dark = Fabricate(:upload)

      parent_category = Fabricate(:category)
      category =
        Fabricate(
          :category,
          parent_category_id: parent_category.id,
          uploaded_background: background,
          uploaded_background_dark: background_dark,
        )

      # light color schemes
      ["Neutral", "Shades of Blue", "WCAG", "Summer", "Solarized Light"].each do |scheme_name|
        scheme = ColorScheme.create_from_base(name: "Light Test", base_scheme_id: scheme_name)

        compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })

        expect(compiled_css).to include(
          "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(#{background.url})}",
        )
        expect(compiled_css).not_to include(background_dark.url)
      end

      # dark color schemes
      [
        "Dark",
        "Grey Amber",
        "Latte",
        "Dark Rose",
        "WCAG Dark",
        "Dracula",
        "Solarized Dark",
      ].each do |scheme_name|
        scheme = ColorScheme.create_from_base(name: "Light Test", base_scheme_id: scheme_name)

        compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })

        expect(compiled_css).not_to include(background.url)
        expect(compiled_css).to include(
          "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(#{background_dark.url})}",
        )
      end
    end

    it "applies CDN to background category images" do
      expect(compile_css("color_definitions")).to_not include("body.category-")

      background = Fabricate(:upload)
      background_dark = Fabricate(:upload)

      parent_category = Fabricate(:category)
      category =
        Fabricate(
          :category,
          parent_category_id: parent_category.id,
          uploaded_background: background,
          uploaded_background_dark: background_dark,
        )

      compiled_css = compile_css("color_definitions")
      expect(compiled_css).to include(
        "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(#{background.url})}",
      )

      GlobalSetting.stubs(:cdn_url).returns("//awesome.cdn")
      compiled_css = compile_css("color_definitions")
      expect(compiled_css).to include(
        "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(//awesome.cdn#{background.url})}",
      )
    end

    it "applies CDN to dark background category images" do
      scheme = ColorScheme.create_from_base(name: "Dark Test", base_scheme_id: "Dark")
      expect(compile_css("color_definitions", { color_scheme_id: scheme.id })).to_not include(
        "body.category-",
      )

      background = Fabricate(:upload)
      background_dark = Fabricate(:upload)

      parent_category = Fabricate(:category)
      category =
        Fabricate(
          :category,
          parent_category_id: parent_category.id,
          uploaded_background: background,
          uploaded_background_dark: background_dark,
        )

      compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })
      expect(compiled_css).to include(
        "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(#{background_dark.url})}",
      )

      GlobalSetting.stubs(:cdn_url).returns("//awesome.cdn")
      compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })
      expect(compiled_css).to include(
        "body.category-#{parent_category.slug}-#{category.slug}{background-image:url(//awesome.cdn#{background_dark.url})}",
      )
    end

    it "applies S3 CDN to background category images" do
      setup_s3
      SiteSetting.s3_use_iam_profile = true
      SiteSetting.s3_upload_bucket = "test"
      SiteSetting.s3_region = "ap-southeast-2"
      SiteSetting.s3_cdn_url = "https://s3.cdn"

      background = Fabricate(:upload_s3)
      category = Fabricate(:category, uploaded_background: background)

      compiled_css = compile_css("color_definitions")
      expect(compiled_css).to include(
        "body.category-#{category.slug}{background-image:url(https://s3.cdn/original",
      )
    end

    it "applies S3 CDN to dark background category images" do
      scheme = ColorScheme.create_from_base(name: "Dark Test", base_scheme_id: "WCAG Dark")

      setup_s3
      SiteSetting.s3_use_iam_profile = true
      SiteSetting.s3_upload_bucket = "test"
      SiteSetting.s3_region = "ap-southeast-2"
      SiteSetting.s3_cdn_url = "https://s3.cdn"

      background = Fabricate(:upload_s3)
      background_dark = Fabricate(:upload_s3)
      category =
        Fabricate(
          :category,
          uploaded_background: background,
          uploaded_background_dark: background_dark,
        )

      compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })
      expect(compiled_css).to include(
        "body.category-#{category.slug}{background-image:url(https://s3.cdn/original",
      )
    end

    describe "stylesheet_importer_categories_with_background_images modifier" do
      fab!(:background) { Fabricate(:upload) }
      fab!(:category_with_background) { Fabricate(:category, uploaded_background: background) }

      fab!(:undesired_background) { Fabricate(:upload) }
      fab!(:category_with_undesired_background) do
        Fabricate(:category, uploaded_background: undesired_background)
      end

      let(:modifier_block) do
        Proc.new do |categories_with_background|
          categories_with_background.where.not(id: category_with_undesired_background.id)
        end
      end

      it "can change which categories have background images applied" do
        # it includes both category backgrounds before the modifier is applied
        scheme = ColorScheme.create_from_base(name: "Light Test", base_scheme_id: "Neutral")
        compiled_css = compile_css("color_definitions", { color_scheme_id: scheme.id })

        expect(compiled_css).to include(
          "body.category-#{category_with_background.slug}{background-image:url(#{background.url})}",
        )
        expect(compiled_css).to include(
          "body.category-#{category_with_undesired_background.slug}{background-image:url(#{undesired_background.url})}",
        )

        # it includes only the desired category background after the modifier is applied
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(
          :stylesheet_importer_categories_with_background_images,
          &modifier_block
        )

        modified_css = compile_css("color_definitions", { color_scheme_id: scheme.id })

        expect(modified_css).to include(
          "body.category-#{category_with_background.slug}{background-image:url(#{background.url})}",
        )
        expect(modified_css).not_to include(
          "body.category-#{category_with_undesired_background.slug}{background-image:url(#{undesired_background.url})}",
        )
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :stylesheet_importer_categories_with_background_images,
          &modifier_block
        )
      end
    end
  end

  describe "#font" do
    it "includes font variable" do
      default_font = ":root{--font-family: Arial, sans-serif}"
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
