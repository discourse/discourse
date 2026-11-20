# frozen_string_literal: true

RSpec.describe Blog::ThemePresets do
  def write_theme(root, folder, manifest: nil, css: nil, templates: {})
    path = File.join(root, folder)
    FileUtils.mkdir_p(File.join(path, "templates"))
    manifest ||= {
      version: 2,
      name: folder.titleize,
      accent_color: "112233",
      paper_color: "fafafa",
      ink_color: "222222",
    }.to_json
    File.write(File.join(path, Blog::ThemeImporter::MANIFEST), manifest)
    File.write(File.join(path, "blog.css"), css) if css
    templates.each do |page, source|
      File.write(File.join(path, "templates/#{page}.liquid"), source)
    end
  end

  describe ".all" do
    it "lists the built-in design first, then each bundled theme" do
      expect(described_class.all.map { |preset| preset["id"] }).to eq(
        %w[default broadsheet discourse-blog],
      )
      expect(described_class.all).to all(include("preset" => true, "revision" => 1))
    end

    it "loads every theme folder shipped under branding/" do
      shipped =
        Dir
          .glob(File.join(described_class::ROOT, "*", Blog::ThemeImporter::MANIFEST))
          .map { |manifest| File.basename(File.dirname(manifest)) }

      logger = track_log_messages { described_class.read_folders(described_class::ROOT) }

      expect(shipped).to be_present
      expect(described_class.all.map { |preset| preset["id"] }).to include(*shipped)
      expect(logger.warnings).to be_empty
      expect(described_class.all).to all(include("description" => be_present))
      expect(described_class.all).to all(
        include(
          "screenshot_light_url" => %r{\A/plugins/blog/images/themes/[\w-]+/light\.jpg\?v=\h{8}\z},
          "screenshot_dark_url" => %r{\A/plugins/blog/images/themes/[\w-]+/dark\.jpg\?v=\h{8}\z},
        ),
      )
    end
  end

  describe ".read_folders" do
    it "keeps valid folders and skips, with a warning, any that could not be saved as a draft" do
      Dir.mktmpdir do |root|
        write_theme(root, "valid", templates: { "index" => "<h1>{{ site.title }}</h1>" })
        write_theme(root, "default")
        write_theme(root, "broken-manifest", manifest: "{")
        write_theme(root, "missing-name", manifest: { version: 2 }.to_json)
        write_theme(root, "broken-template", templates: { "index" => "{% if %}" })
        write_theme(root, "oversized-css", css: "a" * (Blog::BlogTheme::MAX_CODE_BYTES + 1))
        FileUtils.mkdir_p(File.join(root, "not-a-theme"))

        presets = nil
        logger = track_log_messages { presets = described_class.read_folders(root) }

        expect(presets.map { |preset| preset["id"] }).to eq(["valid"])
        expect(presets.first).to include("name" => "Valid", "preset" => true)
        expect(logger.warnings.size).to eq(5)
        %w[default broken-manifest missing-name broken-template oversized-css].each do |folder|
          expect(logger.warnings).to include(a_string_including("#{root}/#{folder}:"))
        end
      end
    end
  end

  describe ".find" do
    it "reads a bundled theme from its folder" do
      preset = described_class.find("discourse-blog")

      expect(preset).to include(
        "name" => "Discourse Blog",
        "accent_color" => "795ee8",
        "javascript" => "",
      )
      expect(preset["css"]).to be_present
      expect(preset["template_index"]).to be_present
    end

    it "keeps the built-in templates for the default design" do
      expect(described_class.find("default")).to include(
        "name" => I18n.t("blog.themes.default"),
        "css" => "",
        "template_layout" => "",
      )
    end

    it "describes a preset in the current locale" do
      expect(described_class.find("broadsheet")["description"]).to eq(
        I18n.t("blog.themes.descriptions.broadsheet"),
      )
    end

    it "returns nil for a draft id" do
      expect(described_class.find(SecureRandom.uuid)).to be_nil
    end
  end
end
