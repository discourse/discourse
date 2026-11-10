# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:revision) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let!(:theme) do
      create_blog_theme(
        {
          name: "Unused draft",
          accent_color: "112233",
          paper_color: "fafafa",
          ink_color: "222222",
          css: "",
          javascript: "",
        },
        user: Discourse.system_user,
      )
    end
    let(:params) { { theme_id: theme["id"], revision: theme["revision"] } }
    let(:dependencies) { { guardian: acting_user.guardian } }

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

    context "when the revision is stale" do
      let(:params) { super().merge(revision: theme["revision"] + 1) }

      it { is_expected.to fail_a_policy(:revision_is_current) }
    end

    context "when the theme is active" do
      before { activate_blog_theme(theme, user: Discourse.system_user) }

      it { is_expected.to fail_a_policy(:theme_is_inactive) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the draft" do
        expect { result }.to change { Blog::BlogTheme.find_by(id: theme["id"]) }.to(nil)
      end

      it "logs the deletion" do
        expect { result }.to change {
          UserHistory.where(acting_user_id: acting_user.id, custom_type: "blog_theme_delete").count
        }.by(1)
      end
    end
  end
end
