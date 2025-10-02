# frozen_string_literal: true

RSpec.describe ColorSchemeColor do
  after { ColorScheme.hex_cache.clear }

  def test_invalid_hex(hex)
    c = described_class.new(hex: hex)
    expect(c).not_to be_valid
    expect(c.errors[:hex]).to be_present
  end

  it "validates hex value" do
    %w[fff ffffff 333333 333 0BeeF0].each do |hex|
      expect(described_class.new(hex: hex)).to be_valid
    end
    [
      "fffff",
      "ffff",
      "ff",
      "f",
      "00000",
      "00",
      "cheese",
      "#666666",
      "#666",
      "555 666",
    ].each { |hex| test_invalid_hex(hex) }
  end

  describe "#no_edits_for_remote_copies" do
    it "prevents editing colors of remote copies" do
      remote_copy =
        Fabricate(
          :color_scheme,
          remote_copy: true,
          color_scheme_colors: [
            Fabricate(:color_scheme_color, name: "primary", hex: "998877"),
            Fabricate(:color_scheme_color, name: "secondary", hex: "553322"),
          ],
        )
      color = remote_copy.color_scheme_colors.first
      color.hex = "111111"
      expect(color.valid?).to eq(false)
      expect(color.errors.full_messages).to include(
        I18n.t("color_schemes.errors.cannot_edit_remote_copies"),
      )
    end
  end
end
