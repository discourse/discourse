# frozen_string_literal: true

RSpec.describe Themes::ExportBlockLayout do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:outlet_name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:theme)

    let(:guardian) { admin.guardian }
    let(:dependencies) { { guardian: } }
    let(:layout_json) do
      { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
    end
    let(:params) { { theme_id: theme.id, outlet_name: "homepage-blocks" } }

    def set_live_field(value = layout_json)
      theme.set_field(target: :common, name: "homepage-blocks", type: :block_layout, value: value)
      theme.save!
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      before { set_live_field }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "with a live field" do
      before { set_live_field }

      it { is_expected.to run_successfully }

      it "returns the canonical filename and pretty-printed content" do
        expect(result.filename).to eq("block_layouts/homepage-blocks.json")
        parsed = JSON.parse(result.content)
        expect(parsed["schema_version"]).to eq(1)
        expect(parsed["layout"].first["block"]).to eq("hero-banner")
        # Pretty-printed (multi-line) for git-diff friendliness.
        expect(result.content).to include("\n")
      end
    end

    context "with a layout_json override (the unpublished draft)" do
      let(:params) do
        {
          theme_id: theme.id,
          outlet_name: "homepage-blocks",
          layout_json: {
            schema_version: 1,
            layout: [{ block: "hero-banner", args: { title: "Draft" } }],
          }.to_json,
        }
      end

      it "exports the override even when no live field exists" do
        expect(result).to run_successfully
        expect(JSON.parse(result.content)["layout"].first["args"]["title"]).to eq("Draft")
      end
    end

    context "with no live field and no override" do
      it { is_expected.to fail_to_find_a_model(:source_value) }
    end

    context "with a malformed override" do
      let(:params) do
        { theme_id: theme.id, outlet_name: "homepage-blocks", layout_json: "{not json" }
      end

      it { is_expected.to fail_a_step(:build_payload) }
    end

    context "when the theme does not exist" do
      let(:params) { { theme_id: 999_999, outlet_name: "homepage-blocks" } }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end
  end
end
