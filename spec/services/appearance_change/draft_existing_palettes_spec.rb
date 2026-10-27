# frozen_string_literal: true

RSpec.describe AppearanceChange::DraftExistingPalettes do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(**attributes) }

    let(:attributes) { { name: "Royal", theme_id: 1, light_palette_id: 1, dark_palette_id: 2 } }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:light_palette_id) }
    it { is_expected.to validate_presence_of(:dark_palette_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:theme)
    fab!(:light_palette) { Fabricate(:color_scheme, theme:) }
    fab!(:dark_palette) { Fabricate(:color_scheme, theme:) }

    let(:params) do
      {
        theme_id: theme.id,
        name: "Royal",
        light_palette_id: light_palette.id,
        dark_palette_id: dark_palette.id,
        site_settings: {
          base_font: "lora",
        },
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the theme doesn't exist" do
      let(:params) { super().merge(theme_id: 0) }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when the user can't edit the theme" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_edit_theme) }
    end

    context "when a palette belongs to another theme" do
      fab!(:other_palette) { Fabricate(:color_scheme, theme: Fabricate(:theme)) }

      let(:params) { super().merge(dark_palette_id: other_palette.id) }

      it { is_expected.to fail_a_policy(:palettes_available_to_theme) }
    end

    context "when a palette isn't one of core's built-in ones" do
      let(:params) { super().merge(light_palette_id: -1000) }

      it { is_expected.to fail_a_policy(:palettes_available_to_theme) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the choice without creating palettes or changing the theme" do
        expect { result }.not_to change { [ColorScheme.count, theme.reload.color_scheme_id] }
        expect(result[:appearance_change]).to have_attributes(
          kind: "existing_palettes",
          name: "Royal",
          theme:,
          light_color_scheme: light_palette,
          dark_color_scheme: dark_palette,
          site_settings: {
            "base_font" => "lora",
          },
          user: acting_user,
          activated_at: nil,
        )
      end
    end

    context "with built-in palettes" do
      let(:params) do
        super().merge(
          light_palette_id: ColorScheme::NAMES_TO_ID_MAP["WCAG"],
          dark_palette_id: ColorScheme::NAMES_TO_ID_MAP["WCAG Dark"],
        )
      end

      # copies saved by an earlier choice would be reused
      before do
        ColorScheme.where(
          base_scheme_id: params.values_at(:light_palette_id, :dark_palette_id),
          via_wizard: true,
        ).destroy_all
      end

      it "saves them the first time they're chosen, as the design wizard does" do
        expect { result }.to change { ColorScheme.where(via_wizard: true).count }.by(2)
        expect(result[:appearance_change].light_color_scheme).to have_attributes(
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["WCAG"],
          via_wizard: true,
        )
        expect { described_class.call(params:, **dependencies) }.not_to change { ColorScheme.count }
      end
    end
  end
end
