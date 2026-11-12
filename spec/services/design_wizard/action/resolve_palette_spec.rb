# frozen_string_literal: true

RSpec.describe DesignWizard::Action::ResolvePalette do
  subject(:result) { described_class.call(palette_id:) }

  context "when no palette is given" do
    let(:palette_id) { nil }

    it { is_expected.to be_nil }

    it "does not materialize anything" do
      expect { result }.not_to change { ColorScheme.count }
    end
  end

  context "when the palette id refers to an existing record" do
    fab!(:palette, :color_scheme)

    let(:palette_id) { palette.id }

    it { is_expected.to eq(palette) }
  end

  context "when the palette id refers to a record that no longer exists" do
    let(:palette_id) { 999_999 }

    it { is_expected.to be_nil }

    it "does not materialize anything" do
      expect { result }.not_to change { ColorScheme.count }
    end
  end

  context "when the palette id refers to a built-in palette" do
    let(:palette_id) { ColorScheme::NAMES_TO_ID_MAP["Dracula"] }

    before { ColorScheme.where(via_wizard: true).destroy_all }

    it "materializes a via_wizard copy named after the built-in palette" do
      expect { result }.to change { ColorScheme.where(via_wizard: true).count }.by(1)

      expect(result).to have_attributes(
        base_scheme_id: palette_id,
        via_wizard: true,
        name: I18n.t("color_schemes.dracula_theme_name"),
      )
    end

    it "reuses the materialized copy on subsequent calls" do
      first = result

      expect { expect(described_class.call(palette_id:)).to eq(first) }.not_to change {
        ColorScheme.where(via_wizard: true).count
      }
    end

    it "copies the built-in colors" do
      expect(result.colors.map(&:name)).to include("primary", "secondary", "tertiary")
    end
  end

  describe "every built-in palette the wizard can offer" do
    let(:palette_id) { nil }

    it "has a translated name" do
      names =
        DesignWizard::PalettePairs::BUILT_IN_PAIRS.flat_map { |pair| pair.values_at(:light, :dark) }

      names.compact.each do |name|
        key = "color_schemes.#{name.downcase.tr(" ", "_")}_theme_name"
        expect(I18n.exists?(key)).to eq(true), "missing translation for #{key}"
      end
    end

    it "can be resolved" do
      DesignWizard::PalettePairs::BUILT_IN_PAIRS
        .flat_map { |pair| pair.values_at(:light, :dark) }
        .compact
        .each do |name|
          resolved = described_class.call(palette_id: ColorScheme::NAMES_TO_ID_MAP[name])
          expect(resolved).to be_present, "could not resolve #{name}"
        end
    end
  end
end
