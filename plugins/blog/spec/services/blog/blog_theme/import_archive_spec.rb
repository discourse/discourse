# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::ImportArchive do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:file) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:archive) do
      Blog::ThemeExporter.export(
        Blog::BlogTheme.defaults.merge("name" => "Archived design", "css" => ".blog {}"),
      )
    end
    let(:file) do
      tempfile = Tempfile.new(%w[blog-theme .zip])
      tempfile.binmode
      tempfile.write(archive)
      tempfile.rewind
      ActionDispatch::Http::UploadedFile.new(tempfile:, filename: "theme.zip")
    end
    let(:params) { { file: } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the archive is invalid" do
      let(:archive) { "not a zip" }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the archive as an inactive draft" do
        expect(result.theme).to include("name" => "Archived design", "css" => ".blog {}")
        expect(Blog::BlogTheme.find(result.theme["id"])).to eq(result.theme)
        expect(Blog::BlogTheme.active["id"]).to be_nil
      end
    end
  end
end
