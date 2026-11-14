# frozen_string_literal: true

RSpec.describe DiscourseWireframe::EnsureBlockLayoutCompanion do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.not_to allow_value(0).for(:theme_id) }
    it { is_expected.to validate_presence_of(:name) }
    # Core system themes (Foundation, Horizon) have negative ids and are valid.
    it { is_expected.to allow_value(-1).for(:theme_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:parent) { Fabricate(:theme_with_remote_url, name: "Acme") }

    let(:dependencies) { { guardian: admin.guardian } }
    let(:layout_json) do
      { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
    end
    let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: layout_json }] }
    let(:params) { { theme_id: parent.id, name: "Spring launch", drafts: drafts } }

    def component
      Theme.find(result.theme_id)
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    it "creates a local component child of the parent, holding the overlaid layout, and records the mapping" do
      expect(result).to run_successfully
      expect(component.component).to eq(true)
      expect(component.remote_theme&.is_git?).to be_falsey
      expect(component.name).to eq("Spring launch")
      expect(parent.reload.child_theme_ids).to include(component.id)

      field =
        component.theme_fields.find_by(
          name: "homepage-blocks",
          type_id: ThemeField.types[:block_layout],
        )
      expect(field).to be_present
      expect(JSON.parse(field.value)["layout"].first["block"]).to eq("hero-banner")

      expect(DiscourseWireframe::BlockLayoutCompanion.companion_id_for(parent.id)).to eq(
        component.id,
      )
    end

    it "installs only the newest design, keeping the earlier one available" do
      first = described_class.call(params:, **dependencies)
      second =
        described_class.call(
          params: {
            theme_id: parent.id,
            name: "Autumn sale",
            drafts: drafts,
          },
          **dependencies,
        )

      expect(second.theme_id).not_to eq(first.theme_id)
      expect(parent.reload.child_theme_ids).to contain_exactly(second.theme_id)
      expect(DiscourseWireframe::BlockLayoutCompanion.companion_id_for(parent.id)).to eq(
        second.theme_id,
      )
      expect(
        DiscourseWireframe::BlockLayoutCompanion.designs_for(parent.id).map { _1[:name] },
      ).to eq(["Autumn sale", "Spring launch"])
    end

    it "suffixes the component name when the name is already taken" do
      Fabricate(:theme, name: "Spring launch", component: false)
      expect(component.name).to eq("Spring launch 2")
    end

    context "with a core system theme as the parent (negative id)" do
      let(:params) do
        { theme_id: Theme.foundation_theme.id, name: "Spring launch", drafts: drafts }
      end

      it "creates the companion component installed on the system theme" do
        foundation = Theme.foundation_theme
        expect(foundation.id).to be < 0

        expect(result).to run_successfully
        expect(component.component).to eq(true)
        expect(component.name).to eq("Spring launch")
        expect(foundation.reload.child_theme_ids).to include(component.id)
        expect(DiscourseWireframe::BlockLayoutCompanion.companion_id_for(foundation.id)).to eq(
          component.id,
        )
      end
    end

    context "with a malformed draft" do
      let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: "{not json" }] }

      it { is_expected.to fail_a_step(:validate_drafts) }
    end

    context "when the theme does not exist" do
      let(:params) { { theme_id: 999_999, name: "x", drafts: [] } }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end
  end
end
