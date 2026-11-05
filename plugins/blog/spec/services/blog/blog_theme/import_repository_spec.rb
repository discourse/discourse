# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::ImportRepository do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:repository) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:repository) { "https://github.com/example/blog-theme" }
    let(:params) { { repository:, branch: "design" } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        example.run
      end
    end

    before do
      File.write(
        File.join(@directory, "blog-theme.json"),
        {
          version: 1,
          name: "Git design",
          accent_color: "112233",
          paper_color: "fafafa",
          ink_color: "222222",
        }.to_json,
      )
      File.write(File.join(@directory, "blog.css"), ".blog { color: red; }")
      importer = ThemeStore::DirectoryImporter.new(@directory)
      importer.stubs(:version).returns("a" * 40)
      Blog::ThemeImporter::GitSource.stubs(:new).returns(importer)
    end

    context "when contract is invalid" do
      let(:params) { { branch: "design" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the repository is unusable" do
      let(:repository) { "http://example.com/repo" }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the repository's theme as an inactive draft" do
        expect(result.theme).to include(
          "name" => "Git design",
          "css" => ".blog { color: red; }",
          "source" => {
            "repository" => repository,
            "branch" => "design",
            "commit" => "a" * 40,
          },
        )
        expect(Blog::BlogTheme.active["id"]).to be_nil
      end
    end
  end
end
