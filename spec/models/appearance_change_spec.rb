# frozen_string_literal: true

RSpec.describe AppearanceChange do
  fab!(:theme)

  describe "validations" do
    it "only allows the font site settings" do
      appearance_change =
        Fabricate.build(:appearance_change, site_settings: { "base_font" => "roboto" })
      expect(appearance_change).to be_valid

      appearance_change.site_settings = { "title" => "Something else" }
      expect(appearance_change).not_to be_valid
    end
  end

  describe ".palette_only_theme_ids" do
    it "lists the themes appearance changes created until files or components are added" do
      palette_only = Fabricate(:theme_appearance_change)
      with_files = Fabricate(:theme_appearance_change)
      with_files.theme.set_field(target: :common, name: :scss, value: "body { color: red; }")
      with_files.theme.save!
      with_component = Fabricate(:theme_appearance_change)
      with_component.theme.add_relative_theme!(:child, Fabricate(:theme, component: true))
      Fabricate(:appearance_change, theme:)

      expect(described_class.palette_only_theme_ids).to contain_exactly(palette_only.theme_id)
    end
  end

  describe "#applied?" do
    it "is true for a new theme once it is the default" do
      appearance_change = Fabricate(:theme_appearance_change)
      expect(appearance_change.applied?).to eq(false)

      appearance_change.theme.set_default!
      expect(appearance_change.applied?).to eq(true)
    end

    it "is true for palettes once the theme has both of them" do
      appearance_change = Fabricate(:appearance_change, theme:)
      theme.update!(color_scheme: appearance_change.light_color_scheme)
      expect(appearance_change.reload.applied?).to eq(false)

      theme.update!(dark_color_scheme: appearance_change.dark_color_scheme)
      expect(appearance_change.reload.applied?).to eq(true)
    end
  end

  describe "#discard!" do
    it "removes a new theme along with its palettes" do
      appearance_change = Fabricate(:theme_appearance_change)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(Theme.exists?(appearance_change.theme_id)).to eq(false)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ),
      ).to be_empty
    end

    it "keeps palettes the site already had" do
      appearance_change = Fabricate(:appearance_change, kind: :existing_palettes)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end

    it "keeps a theme members can choose, and the palettes it uses" do
      appearance_change = Fabricate(:theme_appearance_change)
      appearance_change.theme.update!(user_selectable: true)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(Theme.exists?(appearance_change.theme_id)).to eq(true)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end

    it "keeps palettes another theme uses" do
      appearance_change = Fabricate(:appearance_change, theme:)
      Fabricate(:theme, color_scheme: appearance_change.light_color_scheme)

      appearance_change.discard!

      expect(ColorScheme.exists?(appearance_change.light_color_scheme_id)).to eq(true)
      expect(ColorScheme.exists?(appearance_change.dark_color_scheme_id)).to eq(false)
    end

    it "keeps palettes another change switches back to" do
      appearance_change = Fabricate(:appearance_change, theme:)
      Fabricate(
        :appearance_change,
        theme:,
        previous_state: {
          "color_scheme_id" => appearance_change.light_color_scheme_id,
          "dark_color_scheme_id" => appearance_change.dark_color_scheme_id,
        },
      )

      appearance_change.discard!

      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end
  end
end
