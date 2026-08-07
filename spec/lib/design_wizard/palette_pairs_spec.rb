# frozen_string_literal: true

RSpec.describe DesignWizard::PalettePairs do
  describe ".for_theme" do
    context "when the theme ships no palettes of its own" do
      fab!(:theme)

      it "offers the curated built-in pairs" do
        pairs = described_class.for_theme(theme)

        expect(pairs.map { |pair| pair[:key] }).to eq(%w[default wcag solarized dracula])
      end

      it "names the pairs from the design wizard translations" do
        pairs = described_class.for_theme(theme)

        expect(pairs.map { |pair| pair[:name] }).to eq(
          %w[default wcag solarized dracula].map do |key|
            I18n.t("design_wizard.palette_pairs.#{key}")
          end,
        )
      end

      it "serializes not-yet-materialized built-ins with their negative ids" do
        ColorScheme.where(via_wizard: true).destroy_all

        default_pair = described_class.for_theme(theme).find { |pair| pair[:key] == "default" }

        expect(default_pair[:light][:id]).to eq(ColorScheme::NAMES_TO_ID_MAP["Light"])
        expect(default_pair[:dark][:id]).to eq(ColorScheme::NAMES_TO_ID_MAP["Dark"])
        expect(default_pair[:light][:colors].keys).to include("primary", "secondary", "tertiary")
      end

      it "marks a pair without a light palette as dark only" do
        dracula = described_class.for_theme(theme).find { |pair| pair[:key] == "dracula" }

        expect(dracula[:dark_only]).to eq(true)
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
        expect(pairs.first).to include(key: "royal", name: "Royal", dark_only: false)
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

        expect(pair).to include(key: "clover", dark_only: false)
        expect(pair[:light]).to be_present
        expect(pair[:dark]).to be_nil
      end

      it "treats a dark palette without a light sibling as dark only" do
        Fabricate(:color_scheme, name: "Midnight Dark", theme_id: theme.id)

        pair = described_class.for_theme(theme).first

        expect(pair).to include(key: "midnight", name: "Midnight", dark_only: true)
        expect(pair[:light]).to be_nil
        expect(pair[:dark]).to be_present
      end

      it "does not fall back to the built-in pairs" do
        Fabricate(:color_scheme, name: "Royal", theme_id: theme.id)

        expect(described_class.for_theme(theme).map { |pair| pair[:key] }).not_to include("wcag")
      end
    end
  end
end
