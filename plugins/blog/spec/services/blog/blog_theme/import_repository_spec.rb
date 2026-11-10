# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::ImportRepository do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(repository: "https://github.com/example/blog-theme") }

    it { is_expected.to validate_presence_of(:repository) }
    it { is_expected.to allow_value("https://github.com/example/blog-theme").for(:repository) }

    it do
      is_expected.not_to allow_values(
        "file:///tmp/repo",
        "ssh://git@example.com/repo",
        "http://example.com/repo",
        "https://token@example.com/repo",
        "https://example.com/repo?token=secret",
        "https://example.com/repo#main",
        "https://example.com/#{"a" * Blog::BlogTheme::ImportRepository::MAX_REPOSITORY_LENGTH}",
        "https://exa mple.com/repo",
      ).for(:repository).with_message(I18n.t("blog.themes.repository_invalid"), against: :base)
    end

    it do
      is_expected.to validate_length_of(:branch).is_at_most(
        Blog::BlogTheme::ImportRepository::MAX_BRANCH_LENGTH,
      )
    end

    it { is_expected.to allow_values(nil, "", "design", "release/v2").for(:branch) }
    it { is_expected.not_to allow_values("--upload-pack=evil", "my branch", "a\tb").for(:branch) }

    it "treats a blank branch as the default branch" do
      contract.branch = ""
      contract.validate

      expect(contract.branch).to be_nil
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:repository) { "https://github.com/example/blog-theme" }
    let(:manifest) do
      {
        version: 1,
        name: "Git design",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
      }
    end
    let(:params) { { repository:, branch: "design" } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        example.run
      end
    end

    before do
      File.write(File.join(@directory, "blog-theme.json"), manifest.to_json)
      File.write(File.join(@directory, "blog.css"), ".blog { color: red; }")
      checkout = ThemeStore::DirectoryImporter.new(@directory)
      checkout.stubs(:version).returns("a" * 40)
      Blog::ThemeImporter::GitSource.stubs(:new).returns(checkout)
    end

    context "when contract is invalid" do
      let(:repository) { "http://example.com/repo" }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the repository is not allowed" do
      before do
        GlobalSetting.stubs(:allowed_theme_repos).returns(
          "https://github.com/discourse/another-theme",
        )
      end

      it { is_expected.to fail_a_policy(:can_import_repository) }
    end

    context "when the repository has no readable theme" do
      let(:manifest) { super().merge(version: 99) }

      it { is_expected.to fail_with_exception(Blog::ThemeImporter::InvalidTheme) }
    end

    context "when the repository can't be cloned" do
      before do
        Blog::ThemeImporter::GitSource.unstub(:new)
        FinalDestination.stubs(:resolve).returns(nil)
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns([])
      end

      it { is_expected.to fail_with_exception(RemoteTheme::ImportError) }
    end

    context "when the repository's theme is invalid" do
      let(:manifest) { super().merge(accent_color: "red") }

      it { is_expected.to fail_a_step(:create_theme) }

      it "reports why the theme can't be saved" do
        expect(result["result.step.create_theme"].error).to eq(I18n.t("blog.themes.invalid"))
      end
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
        expect(Blog::BlogTheme.active["id"]).to eq(Blog::ThemePresets::DEFAULT_ID)
      end
    end
  end
end
