# frozen_string_literal: true

RSpec.describe Blog::ThemeImporter do
  let(:manifest) do
    {
      version: 1,
      name: "Café design",
      accent_color: "112233",
      paper_color: "fafafa",
      ink_color: "222222",
    }
  end

  describe ".read_archive" do
    subject(:imported_theme) { described_class.read_archive(archive_with(files)) }

    let(:files) { { "blog-theme.json" => manifest.to_json, "blog.css" => ".blog { color: red; }" } }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        example.run
      end
    end

    def archive_with(entries)
      path = File.join(@directory, "#{SecureRandom.hex}.zip")
      Zip::File.open(path, create: true) do |archive|
        entries.each { |name, content| archive.get_output_stream(name) { it.write(content) } }
      end
      path
    end

    it "reads a legacy manifest inside a single enclosing directory without saving it" do
      files.transform_keys! { "design/#{it}" }

      expect(imported_theme).to have_attributes(
        attributes: {
          "name" => "Café design",
          "accent_color" => "112233",
          "paper_color" => "fafafa",
          "ink_color" => "222222",
          "css" => ".blog { color: red; }",
          "javascript" => "",
        },
        source: nil,
      )
      expect(Blog::BlogTheme.all).to be_empty
    end

    it "reads version-two templates and leaves missing ones blank" do
      files["blog-theme.json"] = manifest.merge(version: 2).to_json
      files["templates/index.liquid"] = "<h1>{{ site.title }}</h1>"

      expect(imported_theme.attributes).to include(
        "template_index" => "<h1>{{ site.title }}</h1>",
        "template_article" => "",
      )
    end

    it "rejects unreadable archives, unsupported manifests, and oversized files" do
      version_two = manifest.merge(version: 2).to_json
      [
        { "about.json" => "{}" },
        { "blog-theme.json" => "not json" },
        { "blog-theme.json" => manifest.merge(version: 99).to_json },
        { "blog-theme.json" => " " * (described_class::MAX_MANIFEST_BYTES + 1) },
        { "blog-theme.json" => version_two, "blog.css" => "a" * 65_537 },
        {
          "blog-theme.json" => version_two,
          "templates/index.liquid" => "a" * (Blog::TemplateRenderer::MAX_TEMPLATE_BYTES + 1),
        },
        (described_class::MAX_ARCHIVE_ENTRIES + 1).times.to_h { ["#{it}.txt", ""] },
      ].each do |entries|
        expect { described_class.read_archive(archive_with(entries)) }.to raise_error(
          described_class::InvalidTheme,
        )
      end
    end

    it "rejects a file that is not a ZIP archive" do
      File.write(File.join(@directory, "theme.zip"), "not a zip")

      expect { described_class.read_archive(File.join(@directory, "theme.zip")) }.to raise_error(
        described_class::InvalidTheme,
        I18n.t("blog.themes.archive_invalid"),
      )
    end
  end

  describe ".read_repository" do
    subject(:imported_theme) { described_class.read_repository(repository, branch: "design") }

    let(:repository) { "https://github.com/example/blog-theme" }
    let(:checkout) { ThemeStore::DirectoryImporter.new(@directory) }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        example.run
      end
    end

    before do
      File.write(File.join(@directory, "blog-theme.json"), manifest.to_json)
      File.write(File.join(@directory, "blog.css"), ".blog { color: red; }")
      File.write(File.join(@directory, "blog.js"), "window.gitTheme = true;")
      checkout.stubs(:version).returns("a" * 40)
      described_class::GitSource.stubs(:new).with(repository, branch: "design").returns(checkout)
    end

    it "reads the theme and its source, then removes the checkout" do
      expect(imported_theme).to have_attributes(
        attributes:
          a_hash_including(
            "name" => "Café design",
            "css" => ".blog { color: red; }",
            "javascript" => "window.gitTheme = true;",
          ),
        source: {
          "repository" => repository,
          "branch" => "design",
          "commit" => "a" * 40,
        },
      )
      expect(File.exist?(checkout.temp_folder)).to eq(false)
      expect(Blog::BlogTheme.all).to be_empty
    end

    it "reads version-two templates" do
      File.write(File.join(@directory, "blog-theme.json"), manifest.merge(version: 2).to_json)
      FileUtils.mkdir_p(File.join(@directory, "templates"))
      File.write(File.join(@directory, "templates/index.liquid"), "<h1>{{ site.title }}</h1>")

      expect(imported_theme.attributes).to include(
        "template_index" => "<h1>{{ site.title }}</h1>",
        "template_article" => "",
      )
    end

    it "ignores symlinks that leave the checkout" do
      checkout.stubs(:import!)
      FileUtils.mkdir_p(checkout.temp_folder)
      File.write(File.join(checkout.temp_folder, "blog-theme.json"), manifest.to_json)
      File.symlink("/etc/passwd", File.join(checkout.temp_folder, "blog.js"))

      expect(imported_theme.attributes["javascript"]).to eq("")
      expect(File.exist?(checkout.temp_folder)).to eq(false)
    end

    it "rejects oversized files and removes the checkout" do
      File.write(File.join(@directory, "blog.js"), "a" * (Blog::BlogTheme::MAX_CODE_BYTES + 1))

      expect { imported_theme }.to raise_error(
        described_class::InvalidTheme,
        I18n.t("blog.themes.file_too_large", file: "blog.js"),
      )
      expect(File.exist?(checkout.temp_folder)).to eq(false)
    end

    it "rejects missing, malformed, and unsupported manifests" do
      ["not json", manifest.merge(version: 99).to_json, nil].each do |content|
        path = File.join(@directory, "blog-theme.json")
        content ? File.write(path, content) : FileUtils.rm_f(path)

        expect { described_class.read_repository(repository, branch: "design") }.to raise_error(
          described_class::InvalidTheme,
          I18n.t("blog.themes.manifest_invalid"),
        )
      end
      expect(File.exist?(checkout.temp_folder)).to eq(false)
    end
  end
end

RSpec.describe Blog::ThemeImporter::GitSource do
  describe "HTTPS transport" do
    it "rejects an HTTPS discovery endpoint that resolves to plain HTTP" do
      FinalDestination.stubs(:resolve).returns(URI("http://example.com/theme/info/refs"))
      importer = described_class.new("https://example.com/theme")
      expect { importer.import! }.to raise_error(RemoteTheme::ImportError)
      expect(File.exist?(importer.temp_folder)).to eq(false)
    end

    it "rejects destinations without a public IP address" do
      FinalDestination.stubs(:resolve).returns(nil)
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns([])
      importer = described_class.new("https://127.0.0.1/theme")
      expect { importer.import! }.to raise_error(RemoteTheme::ImportError)
      expect(File.exist?(importer.temp_folder)).to eq(false)
    end
  end
end
