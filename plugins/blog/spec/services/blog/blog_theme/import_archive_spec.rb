# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::ImportArchive do
  def upload(content, filename: "theme.zip")
    tempfile = Tempfile.new(["blog-theme", File.extname(filename)])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    ActionDispatch::Http::UploadedFile.new(tempfile:, filename:)
  end

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:file) }

    it do
      is_expected.to allow_values(upload("zip"), upload("zip", filename: "THEME.ZIP")).for(:file)
    end

    it do
      is_expected.not_to allow_values(
        "theme.zip",
        upload("zip", filename: "theme.json"),
        upload("a" * (Blog::BlogTheme::ImportArchive::MAX_ARCHIVE_BYTES + 1)),
      ).for(:file)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:theme_attributes) do
      Blog::BlogTheme.defaults.merge("name" => "Archived design", "css" => ".blog {}")
    end
    let(:archive) { Blog::ThemeExporter.export(theme_attributes) }
    let(:params) { { file: upload(archive) } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the archive is unreadable" do
      let(:archive) { "not a zip" }

      it { is_expected.to fail_with_exception(Blog::ThemeImporter::InvalidTheme) }
    end

    context "when the archived theme is invalid" do
      let(:theme_attributes) { super().merge("template_index" => '{% include "/etc/passwd" %}') }

      it { is_expected.to fail_a_step(:create_theme) }

      it "reports why the theme can't be saved" do
        expect(result["result.step.create_theme"].error).to start_with(
          I18n.t("blog.themes.template_parse_error", error: "index: "),
        )
      end
    end

    context "when the theme limit is reached" do
      around { |example| stub_const(Blog::BlogTheme, :MAX_THEMES, 0) { example.run } }

      it { is_expected.to fail_a_step(:create_theme) }

      it "reports the limit" do
        expect(result["result.step.create_theme"].error).to eq(I18n.t("blog.themes.limit"))
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the archive as an inactive draft" do
        expect(result.theme).to include(
          "name" => "Archived design",
          "css" => ".blog {}",
          "revision" => 1,
          "source" => nil,
        )
        expect(Blog::BlogTheme.find(result.theme["id"])).to eq(result.theme)
        expect(Blog::BlogTheme.active["id"]).to eq(Blog::ThemePresets::DEFAULT_ID)
      end
    end
  end
end
