# frozen_string_literal: true

RSpec.describe DesignWizard::Action::UpdatePaletteSelectability do
  subject(:result) { described_class.call(theme:, selectable:) }

  fab!(:theme) { Theme.horizon_theme }

  let(:selectable) { true }

  context "when the theme ships its own palettes" do
    fab!(:theme_palette) { Fabricate(:color_scheme, theme_id: Theme::CORE_THEMES["horizon"]) }
    fab!(:wizard_palette) { Fabricate(:color_scheme, via_wizard: true, user_selectable: true) }

    it "offers the theme palettes" do
      result

      expect(theme_palette.reload.user_selectable).to eq(true)
    end

    it "revokes palettes that are no longer offered" do
      result

      expect(wizard_palette.reload.user_selectable).to eq(false)
    end

    context "without user selectable palettes" do
      let(:selectable) { false }

      it "revokes the theme palettes too" do
        result

        expect(theme_palette.reload.user_selectable).to eq(false)
      end
    end
  end

  context "when the theme ships no palettes of its own" do
    fab!(:theme) { Theme.foundation_theme }
    fab!(:wizard_palette) { Fabricate(:color_scheme, via_wizard: true) }

    before { ColorScheme.where(theme_id: Theme::CORE_THEMES["foundation"]).delete_all }

    it "falls back to offering the wizard palettes" do
      result

      expect(wizard_palette.reload.user_selectable).to eq(true)
    end
  end

  context "when a palette is unrelated to the wizard" do
    fab!(:unrelated_palette) { Fabricate(:color_scheme, user_selectable: true) }
    fab!(:theme_palette) { Fabricate(:color_scheme, theme_id: Theme::CORE_THEMES["horizon"]) }

    it "leaves it untouched" do
      expect { result }.not_to change { unrelated_palette.reload.user_selectable }
    end
  end
end
