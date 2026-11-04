# frozen_string_literal: true

RSpec.describe DesignWizard::PalettePairs do
  describe ".for_theme" do
    context "when the theme ships no palettes of its own" do
      fab!(:theme)

      it "offers the curated built-in pairs" do
        pairs = described_class.for_theme(theme)

        expect(pairs.map { |pair| pair[:key] }).to eq(
          %w[
            default
            wcag
            solarized
            neutral
            shades_of_blue
            summer
            dracula
            grey_amber
            latte
            dark_rose
          ],
        )
      end

      it "names the pairs from the design wizard translations" do
        pairs = described_class.for_theme(theme)

        expect(pairs.map { |pair| pair[:name] }).to eq(
          %w[
            default
            wcag
            solarized
            neutral
            shades_of_blue
            summer
            dracula
            grey_amber
            latte
            dark_rose
          ].map { |key| I18n.t("design_wizard.palette_pairs.#{key}") },
        )
      end

      it "serializes not-yet-materialized built-ins with their negative ids" do
        ColorScheme.where(via_wizard: true).destroy_all

        default_pair = described_class.for_theme(theme).find { |pair| pair[:key] == "default" }

        expect(default_pair[:light][:id]).to eq(ColorScheme::NAMES_TO_ID_MAP["Light"])
        expect(default_pair[:dark][:id]).to eq(ColorScheme::NAMES_TO_ID_MAP["Dark"])
        expect(default_pair[:light][:colors].keys).to include("primary", "secondary", "tertiary")
      end

      it "offers single-mode built-ins only in the mode their colors suit" do
        pairs = described_class.for_theme(theme).index_by { |pair| pair[:key] }

        expect(pairs.values_at("neutral", "shades_of_blue", "summer")).to all(include(dark: nil))
        expect(pairs.values_at("grey_amber", "latte", "dark_rose")).to all(include(light: nil))
      end

      it "leaves a pair without a light palette out of light mode" do
        dracula = described_class.for_theme(theme).find { |pair| pair[:key] == "dracula" }

        expect(dracula[:light]).to be_nil
        expect(dracula[:dark]).to be_present
      end

      it "prefers an already materialized copy over the in-memory built-in" do
        ColorScheme.where(via_wizard: true).destroy_all
        materialized =
          ColorScheme.create_from_base(
            name: "Dracula",
            base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dracula"],
            via_wizard: true,
          )

        dracula = described_class.for_theme(theme).find { |pair| pair[:key] == "dracula" }

        expect(dracula[:dark][:id]).to eq(materialized.id)
      end
    end

    context "when the theme ships its own palettes" do
      fab!(:theme)

      it "pairs them by the '<name>' / '<name> Dark' convention" do
        light = Fabricate(:color_scheme, name: "Royal", theme_id: theme.id)
        dark = Fabricate(:color_scheme, name: "Royal Dark", theme_id: theme.id)

        pairs = described_class.for_theme(theme)

        expect(pairs.size).to eq(1)
        expect(pairs.first).to include(key: "royal", name: "Royal")
        expect(pairs.first[:light][:id]).to eq(light.id)
        expect(pairs.first[:dark][:id]).to eq(dark.id)
      end

      it "parameterizes multi-word names into keys" do
        Fabricate(:color_scheme, name: "Shades of Blue", theme_id: theme.id)

        expect(described_class.for_theme(theme).map { |pair| pair[:key] }).to eq(%w[shades_of_blue])
      end

      it "leaves a light palette without a dark sibling unpaired" do
        Fabricate(:color_scheme, name: "Clover", theme_id: theme.id)

        pair = described_class.for_theme(theme).first

        expect(pair).to include(key: "clover")
        expect(pair[:light]).to be_present
        expect(pair[:dark]).to be_nil
      end

      it "leaves a dark palette without a light sibling unpaired" do
        Fabricate(:color_scheme, name: "Midnight Dark", theme_id: theme.id)

        pair = described_class.for_theme(theme).first

        expect(pair).to include(key: "midnight", name: "Midnight")
        expect(pair[:light]).to be_nil
        expect(pair[:dark]).to be_present
      end

      it "does not fall back to the built-in pairs" do
        Fabricate(:color_scheme, name: "Royal", theme_id: theme.id)

        expect(described_class.for_theme(theme).map { |pair| pair[:key] }).not_to include("wcag")
      end
    end

    context "when admins have created palettes of their own" do
      fab!(:theme)
      fab!(:light_palette) do
        ColorScheme.create_from_base(
          name: "Brand",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"],
        )
      end
      fab!(:dark_palette) do
        ColorScheme.create_from_base(
          name: "Brand Night",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"],
        )
      end

      it "offers them after the built-in pairs, in the mode their colors suit" do
        pairs = described_class.for_theme(theme)

        expect(pairs.map { |pair| pair[:key] }).to eq(
          described_class::BUILT_IN_PAIRS.map { |pair| pair[:key] } +
            %W[custom_#{light_palette.id} custom_#{dark_palette.id}],
        )

        light = pairs.find { |pair| pair[:key] == "custom_#{light_palette.id}" }
        expect(light).to include(name: "Brand", dark: nil)
        expect(light[:light][:id]).to eq(light_palette.id)

        dark = pairs.find { |pair| pair[:key] == "custom_#{dark_palette.id}" }
        expect(dark).to include(name: "Brand Night", light: nil)
        expect(dark[:dark][:id]).to eq(dark_palette.id)
      end

      it "offers them alongside a theme's own palettes" do
        Fabricate(:color_scheme, name: "Royal", theme_id: theme.id)

        expect(described_class.for_theme(theme).map { |pair| pair[:key] }).to eq(
          %W[royal custom_#{light_palette.id} custom_#{dark_palette.id}],
        )
      end

      it "leaves out palettes owned by a theme or saved by the wizard" do
        other_theme = Fabricate(:theme)
        Fabricate(:color_scheme, name: "Other", theme_id: other_theme.id)
        ColorScheme.create_from_base(
          name: "Solarized Light",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Solarized Light"],
          via_wizard: true,
        )

        expect(
          described_class.for_theme(theme).map { |pair| pair[:key] }.grep(/\Acustom_/),
        ).to contain_exactly("custom_#{light_palette.id}", "custom_#{dark_palette.id}")
      end
    end
  end
end
