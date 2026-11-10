# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::Pull do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:revision) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:repository) { "https://github.com/example/blog-theme" }
    let(:attributes) do
      {
        name: "Git design",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
        css: ".blog { color: red; }",
        javascript: "",
      }
    end
    let(:manifest) { attributes.except(:css, :javascript).merge(version: 1) }
    let(:source) { { "repository" => repository, "branch" => "design", "commit" => "a" * 40 } }
    let!(:theme) { create_blog_theme(attributes, user: Discourse.system_user, source:) }
    let(:params) { { theme_id: theme["id"], revision: theme["revision"] } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        example.run
      end
    end

    before do
      File.write(File.join(@directory, "blog-theme.json"), manifest.to_json)
      File.write(File.join(@directory, "blog.css"), ".blog { color: blue; }")
      checkout = ThemeStore::DirectoryImporter.new(@directory)
      checkout.stubs(:version).returns("b" * 40)
      Blog::ThemeImporter::GitSource.stubs(:new).returns(checkout)
    end

    context "when contract is invalid" do
      let(:params) { { theme_id: theme["id"] } }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the theme does not exist" do
      let(:params) { super().merge(theme_id: "missing") }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when the theme was not imported from a repository" do
      let(:source) { nil }

      it { is_expected.to fail_a_policy(:imported_from_repository) }
    end

    context "when the repository is no longer allowed" do
      before do
        GlobalSetting.stubs(:allowed_theme_repos).returns(
          "https://github.com/discourse/another-theme",
        )
      end

      it { is_expected.to fail_a_policy(:can_import_repository) }
    end

    context "when the revision is stale" do
      let(:params) { super().merge(revision: theme["revision"] + 1) }

      it { is_expected.to fail_a_policy(:revision_is_current) }
    end

    context "when the repository has no readable theme" do
      let(:manifest) { super().merge(version: 99) }

      it { is_expected.to fail_with_exception(Blog::ThemeImporter::InvalidTheme) }
    end

    context "when the repository's theme is invalid" do
      let(:manifest) { super().merge(name: "") }

      it { is_expected.to fail_a_step(:revise_theme) }

      it "keeps the saved draft" do
        expect { result }.not_to change { Blog::BlogTheme.find(theme["id"]) }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the repository's latest theme as the next revision" do
        expect(result.pulled_theme).to include(
          "id" => theme["id"],
          "revision" => 2,
          "css" => ".blog { color: blue; }",
          "source" => source.merge("commit" => "b" * 40),
          "locally_modified" => false,
        )
      end
    end
  end
end
