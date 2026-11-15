# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:revision) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:attributes) do
      {
        name: "Quiet draft",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
        css: ".blog { color: red; }",
        javascript: "",
      }
    end
    let(:source) { nil }
    let!(:theme) { create_blog_theme(attributes, user: acting_user, source:) }
    let(:params) do
      attributes.merge(name: "Revised draft", theme_id: theme["id"], revision: theme["revision"])
    end
    let(:options) { {} }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { super().merge(revision: nil) }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      let!(:theme) { create_blog_theme(attributes, user: Discourse.system_user) }

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the theme does not exist" do
      let(:params) { super().merge(theme_id: "missing") }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when the revision is stale" do
      let(:params) { super().merge(revision: theme["revision"] + 1) }

      it { is_expected.to fail_a_policy(:revision_is_current) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the next revision without touching readers" do
        active = activate_blog_theme(theme, user: acting_user)
        expect(result.revised_theme).to include(
          "id" => theme["id"],
          "name" => "Revised draft",
          "revision" => 2,
        )
        expect(Blog::BlogTheme.find(theme["id"])).to eq(result.revised_theme)
        expect(Blog::BlogTheme.active).to eq(active)
      end

      it "logs the save" do
        expect { result }.to change {
          UserHistory.where(acting_user_id: acting_user.id, custom_type: "blog_theme_save").count
        }.by(1)
      end
    end

    context "when editing a Git-imported draft by hand" do
      let(:source) { { "repository" => "https://github.com/example/theme", "commit" => "abc" } }

      it "keeps the source and marks the draft as diverged" do
        expect(result.revised_theme).to include("source" => source, "locally_modified" => true)
      end
    end

    context "when pulling a newer source" do
      let(:source) { { "repository" => "https://github.com/example/theme", "commit" => "abc" } }
      let(:options) { { source: source.merge("commit" => "def") } }

      it "replaces the source and clears the local modification" do
        expect(result.revised_theme).to include(
          "source" => options[:source],
          "locally_modified" => false,
        )
      end
    end
  end
end
