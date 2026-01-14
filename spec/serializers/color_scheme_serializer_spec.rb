# frozen_string_literal: true

RSpec.describe ColorSchemeSerializer do
  fab!(:color_scheme) do
    Fabricate(
      :color_scheme,
      name: "Test Scheme",
      base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["WCAG"],
    )
  end

  describe "#colors" do
    it "returns colors sorted in a specific order" do
      expect(
        described_class.new(color_scheme, root: false).as_json[:colors].map { |c| c[:name] },
      ).to eq(
        %w[
          primary
          secondary
          tertiary
          quaternary
          header_background
          header_primary
          selected
          hover
          highlight
          danger
          success
          love
          primary-medium
          primary-low-mid
          highlight-high
          highlight-medium
          highlight-low
        ] + color_scheme.colors.map(&:name).sort,
      )
    end
  end
end
