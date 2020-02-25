# frozen_string_literal: true

require 'rails_helper'
require 'theme_store/zip_exporter'

describe ThemeStore::ZipExporter do
  let(:rand_hex) do
    +"X" << SecureRandom.hex
  end
  let!(:theme) do
    Fabricate(:theme, name: "Header Icons").tap do |theme|
      theme.set_field(target: :common, name: :body_tag, value: "<b>testtheme1</b>")
      theme.set_field(target: :settings, name: :yaml, value: "somesetting: #{rand_hex}")
      theme.set_field(target: :mobile, name: :scss, value: 'body {background-color: $background_color; font-size: $font-size}')
      theme.set_field(target: :translations, name: :en, value: { en: { key: "value" } }.deep_stringify_keys.to_yaml)
      image = file_from_fixtures("logo.png")
      upload = UploadCreator.new(image, "logo.png").create_for(Discourse::SYSTEM_USER_ID)
      theme.set_field(target: :common, name: :logo, upload_id: upload.id, type: :theme_upload_var)
      image = file_from_fixtures("logo.png")
      _other_upload = UploadCreator.new(image, "logo.png").create_for(Discourse::SYSTEM_USER_ID)
      theme.set_field(target: :common, name: "other_logo", upload_id: upload.id, type: :theme_upload_var)
      theme.build_remote_theme(remote_url: "", about_url: "abouturl", license_url: "licenseurl",
                               authors: "David Taylor", theme_version: "1.0", minimum_discourse_version: "1.0.0",
                               maximum_discourse_version: "3.0.0.beta1")

      cs1 = Fabricate(:color_scheme, name: 'Orphan Color Scheme', color_scheme_colors: [
        Fabricate(:color_scheme_color, name: 'header_primary',  hex: 'F0F0F0'),
        Fabricate(:color_scheme_color, name: 'header_background', hex: '1E1E1E'),
        Fabricate(:color_scheme_color, name: 'tertiary', hex: '858585')
      ])

      cs2 = Fabricate(:color_scheme, name: 'Theme Color Scheme', color_scheme_colors: [
        Fabricate(:color_scheme_color, name: 'header_primary',  hex: 'F0F0F0'),
        Fabricate(:color_scheme_color, name: 'header_background', hex: '1E1E1E'),
        Fabricate(:color_scheme_color, name: 'tertiary', hex: '858585')
      ])

      theme.color_scheme = cs1
      cs2.update(theme_id: theme.id)

      theme.save!
    end
  end

  let(:dir) do
    tmpdir = Dir.tmpdir
    dir = "#{tmpdir}/#{SecureRandom.hex}"
    FileUtils.mkdir(dir)
    dir
  end

  after do
    FileUtils.rm_rf(dir)
  end

  let(:package) do
    exporter = ThemeStore::ZipExporter.new(theme)
    filename = exporter.package_filename
    FileUtils.cp(filename, dir)
    exporter.cleanup!
    "#{dir}/discourse-header-icons.zip"
  end

  it "exports the theme correctly" do
    package
    file = 'discourse-header-icons.zip'
    Dir.chdir(dir) do
      available_size = SiteSetting.decompressed_theme_max_file_size_mb
      Compression::Zip.new.decompress(dir, file, available_size, allow_non_root_folder: true)
      `rm #{file}`

      folders = Dir.glob("**/*").reject { |f| File.file?(f) }
      expect(folders).to contain_exactly("assets", "common", "locales", "mobile")

      files = Dir.glob("**/*").reject { |f| File.directory?(f) }
      expect(files).to contain_exactly("about.json", "assets/logo.png", "assets/other_logo.png", "common/body_tag.html", "locales/en.yml", "mobile/mobile.scss", "settings.yml")

      expect(JSON.parse(File.read('about.json')).deep_symbolize_keys).to eq(
        "name": "Header Icons",
        "about_url": "abouturl",
        "license_url": "licenseurl",
        "component": false,
        "assets": {
          "logo": "assets/logo.png",
          "other_logo": "assets/other_logo.png"
        },
        "authors": "David Taylor",
        "minimum_discourse_version": "1.0.0",
        "maximum_discourse_version": "3.0.0.beta1",
        "theme_version": "1.0",
        "color_schemes": {
          "Orphan Color Scheme": {
            "header_primary": "F0F0F0",
            "header_background": "1E1E1E",
            "tertiary": "858585"
          },
          "Theme Color Scheme": {
            "header_primary": "F0F0F0",
            "header_background": "1E1E1E",
            "tertiary": "858585"
          }
        },
        "learn_more": "https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966"
      )

      expect(File.read("common/body_tag.html")).to eq("<b>testtheme1</b>")
      expect(File.read("mobile/mobile.scss")).to eq("body {background-color: $background_color; font-size: $font-size}")
      expect(File.read("settings.yml")).to eq("somesetting: #{rand_hex}")
      expect(File.read("locales/en.yml")).to eq({ en: { key: "value" } }.deep_stringify_keys.to_yaml)

      theme.update!(name: "Discourse Header Icons")
      exporter = ThemeStore::ZipExporter.new(theme)
      filename = exporter.package_filename
      exporter.cleanup!
      expect(filename).to end_with "/discourse-header-icons.zip"
    end
  end

  it "has safeguards to prevent writing outside the temp directory" do
    # Theme field names should be sanitized before writing to the database,
    # but protection is in place 'just in case'
    expect do
      theme.set_field(target: :translations, name: SiteSetting.default_locale, value: "hacked")
      ThemeField.any_instance.stubs(:file_path).returns("../../malicious")
      theme.save!
      package
    end.to raise_error(RuntimeError)
  end

end
