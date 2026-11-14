# frozen_string_literal: true

RSpec.describe DiscourseWireframe::DeleteDesign do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:design_id) }
    it { is_expected.to allow_value(-1).for(:theme_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:parent) { Fabricate(:theme, name: "Acme") }
    fab!(:design) { Fabricate(:theme, name: "Spring launch", component: true) }

    let(:dependencies) { { guardian: admin.guardian } }
    let(:params) { { theme_id: parent.id, design_id: design.id } }

    before do
      parent.add_relative_theme!(:child, design)
      DiscourseWireframe::BlockLayoutCompanion.create!(
        parent_theme_id: parent.id,
        component_theme_id: design.id,
      )
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the theme is not a design of the parent" do
      let(:params) { { theme_id: parent.id, design_id: Fabricate(:theme, component: true).id } }

      it { is_expected.to fail_to_find_a_model(:mapping) }
    end

    it "removes the design, its mapping and its drafts, and uninstalls it" do
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: admin,
        theme_id: design.id,
        outlet: "homepage-blocks",
        data: "{}",
      )

      expect(result).to run_successfully
      expect(Theme.exists?(design.id)).to eq(false)
      expect(DiscourseWireframe::BlockLayoutCompanion.designs_for(parent.id)).to be_empty
      expect(parent.reload.child_theme_ids).to be_empty
      expect(DiscourseWireframe::BlockLayoutDraft.where(theme_id: design.id)).to be_empty
    end
  end
end
