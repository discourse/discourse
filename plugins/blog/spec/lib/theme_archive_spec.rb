# frozen_string_literal: true

RSpec.describe Blog::ThemeImporter do
  fab!(:admin)

  let(:attributes) do
    Blog::BlogTheme.defaults.merge(
      "name" => "Café design",
      "css" => ".blog { color: red; }",
      "javascript" => "window.blogTheme = true;",
      "template_index" => "<h1>{{ site.title }}</h1>",
    )
  end

  def upload_archive(content, filename: "theme.zip")
    Tempfile.create(%w[blog-theme .zip]) do |file|
      file.binmode
      file.write(content)
      file.flush
      yield(ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: filename))
    end
  end

  def archive_with(files)
    Zip::OutputStream
      .write_buffer do |archive|
        files.each do |name, content|
          archive.put_next_entry(name)
          archive.write(content)
        end
      end
      .string
  end

  describe ".import_file" do
    it "round-trips all theme fields into an independent draft without activating it" do
      source = { "repository" => "https://github.com/example/theme", "commit" => "abc" }
      theme = Blog::BlogTheme.save(attributes, user: admin, source: source)
      active = Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)
      exported = Blog::ThemeExporter.export(theme)

      Zip::File.open_buffer(exported) do |archive|
        expect(archive.entries.map(&:name)).to contain_exactly(
          "blog-theme.json",
          "blog.css",
          "blog.js",
          *Blog::TemplateRenderer::PAGES.map { |page| "templates/#{page}.liquid" },
        )
        expect(JSON.parse(archive.read("blog-theme.json"))).to eq(
          attributes.slice("name", "accent_color", "paper_color", "ink_color").merge(
            "version" => 2,
          ),
        )
      end

      upload_archive(exported) do |file|
        imported = described_class.import_file(file: file, user: admin)
        expect(imported.slice(*Blog::BlogTheme::FIELDS)).to eq(attributes)
        expect(imported["id"]).not_to eq(theme["id"])
        expect(imported["revision"]).to eq(1)
        expect(imported["source"]).to be_nil
        expect(Blog::BlogTheme.active).to eq(active)
      end
    end

    it "accepts a single enclosing directory and legacy manifests" do
      files = {
        "design/blog-theme.json" => attributes.merge("version" => 1).to_json,
        "design/blog.css" => attributes["css"],
      }
      upload_archive(archive_with(files)) do |file|
        imported = described_class.import_file(file: file, user: admin)
        expect(imported["name"]).to eq(attributes["name"])
        expect(imported["css"]).to eq(attributes["css"])
        expect(imported["javascript"]).to eq("")
        expect(imported["template_index"]).to eq("")
      end
    end

    it "rejects invalid archives, unsupported manifests, oversized files, and invalid templates" do
      manifest = attributes.merge("version" => 2).to_json
      [
        "not a zip",
        archive_with("about.json" => "{}"),
        archive_with("blog-theme.json" => "not json"),
        archive_with("blog-theme.json" => attributes.merge("version" => 99).to_json),
        archive_with("blog-theme.json" => " " * 4097),
        archive_with("blog-theme.json" => manifest, "blog.css" => "a" * 65_537),
        archive_with("blog-theme.json" => manifest, "blog.js" => "\xFF".b),
        archive_with(
          "blog-theme.json" => manifest,
          "templates/index.liquid" => '{% include "/etc/passwd" %}',
        ),
        archive_with(
          "blog-theme.json" => manifest,
          "templates/index.liquid" => "a" * (Blog::TemplateRenderer::MAX_TEMPLATE_BYTES + 1),
        ),
        archive_with(1001.times.to_h { |index| ["#{index}.txt", ""] }),
      ].each do |content|
        upload_archive(content) do |file|
          expect { described_class.import_file(file: file, user: admin) }.to raise_error(
            Discourse::InvalidParameters,
          )
        end
      end
      expect(Blog::BlogTheme.all).to be_empty
    end

    it "validates the upload type, extension, and compressed size" do
      expect { described_class.import_file(file: "theme.zip", user: admin) }.to raise_error(
        Discourse::InvalidParameters,
      )
      upload_archive("zip", filename: "theme.json") do |file|
        expect { described_class.import_file(file: file, user: admin) }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
      upload_archive("a" * (2.megabytes + 1)) do |file|
        expect { described_class.import_file(file: file, user: admin) }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
      expect(Blog::BlogTheme.all).to be_empty
    end
  end
end
