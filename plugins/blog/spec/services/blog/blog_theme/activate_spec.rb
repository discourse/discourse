# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::Activate do
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
          name: "Next design",
          accent_color: "112233",
          paper_color: "fafafa",
          ink_color: "222222",
          css: ".blog { color: red; }",
          javascript: "",
        },
        user: Discourse.system_user,
      )
    end
    let(:params) { { theme_id: theme["id"], revision: theme["revision"] } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { revision: theme["revision"] } }

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

    context "when another activation holds the lock" do
      before { DistributedMutex.stubs(:synchronize).returns(nil) }

      it "publishes nothing" do
        expect(result).to be_a_failure
        expect(result["result.lock."]).to be_a_failure
        expect(PluginStore.get(Blog::BlogTheme::STORE, "active")).to be_nil
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "serves readers a frozen snapshot of the draft" do
        expect(result.active_theme).to eq(
          theme.merge("snapshot" => result.active_theme["snapshot"]),
        )
        expect(Blog::BlogTheme.active).to eq(result.active_theme)
        expect(Blog::BlogTheme.snapshot(result.active_theme["snapshot"])).to eq(result.active_theme)
      end

      it "keeps only the newest snapshots" do
        stub_const(Blog::BlogTheme, :MAX_SNAPSHOTS, 1) do
          previous = activate_blog_theme(theme, user: Discourse.system_user)
          result
          expect { Blog::BlogTheme.snapshot(previous["snapshot"]) }.to raise_error(
            Discourse::NotFound,
          )
          expect(Blog::BlogTheme.snapshot(result.active_theme["snapshot"])).to be_present
        end
      end

      it "logs the activation" do
        expect { result }.to change {
          UserHistory.where(
            acting_user_id: acting_user.id,
            custom_type: "blog_theme_activate",
          ).count
        }.by(1)
      end
    end
  end
end
