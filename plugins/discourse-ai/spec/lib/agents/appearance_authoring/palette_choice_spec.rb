# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::AppearanceAuthoring::PaletteChoice do
  before { enable_current_plugin }

  describe ".closest" do
    def closest(theme, brand, **colors)
      described_class.closest(theme:, brand:, **colors)
    end

    it "picks the palettes whose links and buttons come closest to the brand color" do
      SystemThemesManager.sync_theme!("horizon")
      horizon = Theme.horizon_theme

      expect(
        %w[635bff 1ed760 e8590c ff69b4 1f7bc1].map { |brand| closest(horizon, brand).name },
      ).to eq(%w[Horizon Clover Marigold Lily Royal])
    end

    it "returns the palettes' ids and colors" do
      SystemThemesManager.sync_theme!("horizon")
      clover = ColorScheme.find_by(theme: Theme.horizon_theme, name: "Clover")
      clover_dark = ColorScheme.find_by(theme: Theme.horizon_theme, name: "Clover Dark")

      choice = closest(Theme.horizon_theme, "1ed760")

      expect(choice).to have_attributes(
        light_palette_id: clover.id,
        dark_palette_id: clover_dark.id,
      )
      expect(choice.light_colors["tertiary"]).to eq("39845b")
      expect(choice.dark_colors).to all(satisfy { |_, hex| hex.match?(/\A\h{6}\z/) })
    end

    it "weighs in the header and accent colors when they're given" do
      foundation = Theme.foundation_theme

      # Default and Solarized share their link color, but not their header
      expect(closest(foundation, "0088cc").name).to eq("Default")
      expect(closest(foundation, "0088cc", header: "fcf6e1").name).to eq("Solarized")
    end

    it "leaves out pairs without a light palette" do
      expect(closest(Theme.foundation_theme, "bd93f9").name).not_to eq("Dracula")
    end
  end
end
