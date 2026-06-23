# frozen_string_literal: true

RSpec.describe DiscourseWireframe::DiscardBlockLayoutDraft do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:theme)

    let(:dependencies) { { guardian: admin.guardian } }
    let(:params) { { theme_id: theme.id, outlet_name: "homepage-blocks" } }

    def draft_for(user)
      DiscourseWireframe::BlockLayoutDraft.where(user:, theme:, outlet: "homepage-blocks")
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    it "deletes the caller's draft" do
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: admin,
        theme: theme,
        outlet: "homepage-blocks",
        data: "{}",
      )

      expect(result).to be_a_success
      expect(draft_for(admin)).to be_empty
    end

    it "is idempotent when no draft exists" do
      expect(result).to be_a_success
    end

    it "discards a system theme's draft (negative id), e.g. Foundation" do
      foundation = Theme.foundation_theme
      expect(foundation.id).to be < 0
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: admin,
        theme_id: foundation.id,
        outlet: "homepage-blocks",
        data: "{}",
      )

      expect(
        described_class.call(params: params.merge(theme_id: foundation.id), **dependencies),
      ).to be_a_success
      expect(
        DiscourseWireframe::BlockLayoutDraft.where(
          user: admin,
          theme_id: foundation.id,
          outlet: "homepage-blocks",
        ),
      ).to be_empty
    end

    it "leaves another user's draft untouched" do
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: user,
        theme: theme,
        outlet: "homepage-blocks",
        data: "{}",
      )

      described_class.call(params:, **dependencies)
      expect(draft_for(user).count).to eq(1)
    end
  end
end
