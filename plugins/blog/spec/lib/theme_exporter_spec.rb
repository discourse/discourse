# frozen_string_literal: true

RSpec.describe Blog::ThemeExporter do
  describe ".export" do
    subject(:archive) { described_class.export(theme) }

    let(:theme) do
      Blog::BlogTheme.defaults.merge(
        "id" => SecureRandom.uuid,
        "revision" => 3,
        "source" => {
          "repository" => "https://github.com/example/theme",
        },
        "name" => "Café design",
        "css" => ".blog { color: red; }",
        "javascript" => "window.blogTheme = true;",
        "template_index" => "<h1>{{ site.title }}</h1>",
      )
    end

    it "writes every theme file and a version-two manifest" do
      Zip::File.open_buffer(archive) do |zip|
        expect(zip.entries.map(&:name)).to contain_exactly(
          "blog-theme.json",
          "blog.css",
          "blog.js",
          *Blog::TemplateRenderer::PAGES.map { "templates/#{it}.liquid" },
        )
        expect(JSON.parse(zip.read("blog-theme.json"))).to eq(
          theme.slice("name", *Blog::BlogTheme::COLOR_FIELDS).merge("version" => 2),
        )
      end
    end

    it "round-trips every editable field through the importer" do
      Tempfile.create(%w[blog-theme .zip]) do |file|
        file.binmode
        file.write(archive)
        file.flush

        expect(Blog::ThemeImporter.read_archive(file.path).attributes).to eq(
          theme.slice(*Blog::BlogTheme::FIELDS),
        )
      end
    end
  end
end
