# frozen_string_literal: true

RSpec.describe Blog::ThemeImporter do
  fab!(:admin)

  let(:manifest) do
    {
      version: 1,
      name: "Git design",
      accent_color: "112233",
      paper_color: "fafafa",
      ink_color: "222222",
    }
  end
  let(:repository) { "https://github.com/example/blog-theme" }

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
    @importer = ThemeStore::DirectoryImporter.new(@directory)
    @importer.stubs(:version).returns("a" * 40)
    described_class::GitSource.stubs(:new).returns(@importer)
  end

  describe ".import" do
    it "imports a versioned draft and refreshes it without changing the active snapshot" do
      theme = described_class.import(repository: repository, branch: "design", user: admin)
      expect(theme["css"]).to eq(".blog { color: red; }")
      expect(theme["javascript"]).to eq("window.gitTheme = true;")
      expect(theme["source"]).to eq(
        "repository" => repository,
        "branch" => "design",
        "commit" => "a" * 40,
      )
      expect(File.exist?(@importer.temp_folder)).to eq(false)
      Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)
      File.write(File.join(@directory, "blog.css"), ".blog { color: blue; }")
      updated =
        described_class.import(
          repository: repository,
          branch: "design",
          user: admin,
          id: theme["id"],
          revision: 1,
        )
      expect(updated["revision"]).to eq(2)
      expect(updated["css"]).to eq(".blog { color: blue; }")
      expect(Blog::BlogTheme.active["css"]).to eq(theme["css"])
      expect(File.exist?(@importer.temp_folder)).to eq(false)
    end

    it "cleans up and keeps the saved draft when a pull has an invalid or oversized file" do
      theme = described_class.import(repository: repository, branch: nil, user: admin)
      File.write(File.join(@directory, "blog.js"), "a" * 65_537)
      expect do
        described_class.import(
          repository: repository,
          branch: nil,
          user: admin,
          id: theme["id"],
          revision: 1,
        )
      end.to raise_error(Discourse::InvalidParameters)
      expect(Blog::BlogTheme.find(theme["id"])["revision"]).to eq(1)
      expect(File.exist?(@importer.temp_folder)).to eq(false)
      File.write(File.join(@directory, "blog-theme.json"), "not json")
      expect do
        described_class.import(repository: repository, branch: nil, user: admin)
      end.to raise_error(Discourse::InvalidParameters)
      expect(File.exist?(@importer.temp_folder)).to eq(false)
    end

    it "requires the explicit version and prevents out-of-repository symlink reads" do
      File.write(File.join(@directory, "blog-theme.json"), manifest.merge(version: 99).to_json)
      expect do
        described_class.import(repository: repository, branch: nil, user: admin)
      end.to raise_error(Discourse::InvalidParameters)
      File.write(File.join(@directory, "blog-theme.json"), manifest.to_json)
      @importer.stubs(:import!)
      FileUtils.mkdir_p(@importer.temp_folder)
      File.write(File.join(@importer.temp_folder, "blog-theme.json"), manifest.to_json)
      File.symlink("/etc/passwd", File.join(@importer.temp_folder, "blog.js"))
      theme = described_class.import(repository: repository, branch: nil, user: admin)
      expect(theme["javascript"]).to be_empty
      expect(File.exist?(@importer.temp_folder)).to eq(false)
    end

    it "imports bounded version-two templates and rejects invalid Liquid without changing the saved theme" do
      File.write(File.join(@directory, "blog-theme.json"), manifest.merge(version: 2).to_json)
      FileUtils.mkdir_p(File.join(@directory, "templates"))
      File.write(File.join(@directory, "templates/index.liquid"), "<h1>{{ site.title }}</h1>")
      theme = described_class.import(repository: repository, branch: nil, user: admin)
      expect(theme["template_index"]).to eq("<h1>{{ site.title }}</h1>")
      expect(theme["template_article"]).to eq("")
      File.write(File.join(@directory, "templates/index.liquid"), '{% include "/etc/passwd" %}')
      expect do
        described_class.import(
          repository: repository,
          branch: nil,
          user: admin,
          id: theme["id"],
          revision: 1,
        )
      end.to raise_error(Discourse::InvalidParameters)
      expect(Blog::BlogTheme.find(theme["id"])["revision"]).to eq(1)
      expect(File.exist?(@importer.temp_folder)).to eq(false)
    end

    it "rejects unsafe repository protocols, credentials, branch options, and disallowed repositories" do
      %w[
        file:///tmp/repo
        ssh://git@example.com/repo
        http://example.com/repo
        https://token@example.com/repo
        https://example.com/repo?token=secret
      ].each do |url|
        expect do
          described_class.import(repository: url, branch: nil, user: admin)
        end.to raise_error(Discourse::InvalidParameters)
      end
      expect do
        described_class.import(repository: repository, branch: "--upload-pack=evil", user: admin)
      end.to raise_error(Discourse::InvalidParameters)
      GlobalSetting.stubs(:allowed_theme_repos).returns(
        "https://github.com/discourse/another-theme",
      )
      expect do
        described_class.import(repository: repository, branch: nil, user: admin)
      end.to raise_error(Discourse::InvalidAccess)
      expect(Blog::BlogTheme.all).to be_empty
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
