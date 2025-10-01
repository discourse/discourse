# frozen_string_literal: true

RSpec.describe ColorScheme do
  after { ColorScheme.hex_cache.clear }

  let(:valid_params) { { name: "Best Colors Evar", colors: valid_colors } }

  let(:valid_colors) do
    [
      { name: "$primary_background_color", hex: "FFBB00" },
      { name: "$secondary_background_color", hex: "888888" },
    ]
  end

  it "correctly invalidates theme css when changed" do
    scheme = ColorScheme.create_from_base(name: "Bob")
    theme = Fabricate(:theme, color_scheme_id: scheme.id)
    theme.set_field(name: :scss, target: :desktop, value: ".bob {color: $primary;}")
    theme.save!

    manager = Stylesheet::Manager.new(theme_id: theme.id)
    href = manager.stylesheet_data(:desktop_theme)[0][:new_href]
    colors_href = manager.color_scheme_stylesheet_details(scheme.id, fallback_to_base: true)

    ColorSchemeRevisor.revise(scheme, colors: [{ name: "primary", hex: "bbb" }])

    href2 = manager.stylesheet_data(:desktop_theme)[0][:new_href]
    colors_href2 = manager.color_scheme_stylesheet_details(scheme.id, fallback_to_base: true)

    expect(href).not_to eq(href2)
    expect(colors_href).not_to eq(colors_href2)
  end

  describe "new" do
    it "can take colors" do
      c = ColorScheme.new(valid_params)
      expect(c.colors.size).to eq valid_colors.size
      expect(c.colors.first).to be_a(ColorSchemeColor)
      expect { expect(c.save).to eq true }.to change { ColorSchemeColor.count }.by(
        valid_colors.size,
      )
    end
  end

  describe "create_from_base" do
    let(:base_colors) { { first_one: "AAAAAA", second_one: "333333", third_one: "BEEBEE" } }
    let!(:base) do
      Fabricate(
        :color_scheme,
        name: "Base",
        color_scheme_colors: [
          Fabricate(:color_scheme_color, name: "first_one", hex: base_colors[:first_one]),
          Fabricate(:color_scheme_color, name: "second_one", hex: base_colors[:second_one]),
          Fabricate(:color_scheme_color, name: "third_one", hex: base_colors[:third_one]),
        ],
      )
    end

    before { ColorScheme.stubs(:base).returns(base) }

    it "creates a new color scheme" do
      c =
        described_class.create_from_base(
          name: "Yellow",
          colors: {
            first_one: "FFFF00",
            third_one: "F00D33",
          },
        )
      expect(c.colors.size).to eq base_colors.size
      first = c.colors.find { |x| x.name == "first_one" }
      second = c.colors.find { |x| x.name == "second_one" }
      third = c.colors.find { |x| x.name == "third_one" }
      expect(first.hex).to eq "FFFF00"
      expect(second.hex).to eq base_colors[:second_one]
      expect(third.hex).to eq "F00D33"
    end

    context "with hex_for_name without anything enabled" do
      before { ColorScheme.hex_cache.clear }

      it "returns nil for a missing attribute" do
        expect(ColorScheme.hex_for_name("undefined")).to eq nil
      end

      it "returns the base color for an attribute of a specified scheme" do
        scheme = ColorScheme.create_from_base(name: "test scheme")
        ColorSchemeRevisor.revise(
          scheme,
          colors: [{ name: "header_background", hex: "9dc927", default_hex: "949493" }],
        )
        scheme.reload
        expect(ColorScheme.hex_for_name("header_background", scheme.id)).to eq("9dc927")
      end

      it "returns the base color for an attribute" do
        expect(ColorScheme.hex_for_name("second_one")).to eq base_colors[:second_one]
      end
    end
  end

  describe "is_dark?" do
    it "works as expected" do
      scheme = ColorScheme.create_from_base(name: "Tester")
      ColorSchemeRevisor.revise(
        scheme,
        colors: [{ name: "primary", hex: "333333" }, { name: "secondary", hex: "DDDDDD" }],
      )
      expect(scheme.is_dark?).to eq(false)

      ColorSchemeRevisor.revise(
        scheme,
        colors: [{ name: "primary", hex: "F8F8F8" }, { name: "secondary", hex: "232323" }],
      )
      expect(scheme.is_dark?).to eq(true)
    end

    it "does not break in scheme without colors" do
      scheme = ColorScheme.create(name: "No Bueno")
      expect(scheme.is_dark?).to eq(nil)
    end
  end

  describe "is_wcag?" do
    it "works as expected" do
      expect(ColorScheme.create_from_base(name: "Nope").is_wcag?).to eq(false)
      expect(
        ColorScheme.create_from_base(
          name: "Nah",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"],
        ).is_wcag?,
      ).to eq(false)

      expect(
        ColorScheme.create_from_base(
          name: "Yup",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["WCAG"],
        ).is_wcag?,
      ).to eq(true)
      expect(
        ColorScheme.create_from_base(
          name: "Yup",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["WCAG Dark"],
        ).is_wcag?,
      ).to eq(true)
    end
  end

  describe "#resolved_colors" do
    it "merges database colors with base scheme" do
      color_scheme = ColorScheme.new
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "primary", hex: "121212")
      resolved = color_scheme.resolved_colors
      expect(resolved["primary"]).to eq("121212")
      expect(resolved["secondary"]).to eq(ColorScheme.base_colors["secondary"])
    end

    it "falls back to default scheme if base scheme does not have color" do
      custom_color_scheme = Fabricate(:color_scheme)
      Fabricate(
        :color_scheme_color,
        color_scheme: custom_color_scheme,
        name: "secondary",
        hex: "123123",
      )
      color_scheme = ColorScheme.new(base_scheme_id: custom_color_scheme.id)
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "primary", hex: "121212")

      resolved = color_scheme.resolved_colors
      expect(resolved["primary"]).to eq("121212") # From db
      expect(resolved["secondary"]).to eq("123123") # From custom scheme
      expect(resolved["tertiary"]).to eq("08c") # From `foundation/colors.scss`
    end

    it "calculates 'hover' and 'selected' from existing db colors in dark mode" do
      color_scheme = ColorScheme.new
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "primary", hex: "ddd")
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "secondary", hex: "222")
      resolved = color_scheme.resolved_colors
      expect(resolved["hover"]).to eq("313131")
      expect(resolved["selected"]).to eq("2c2c2c")
    end

    it "calculates 'hover' and 'selected' from existing db colors in light mode" do
      color_scheme = ColorScheme.new
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "primary", hex: "222")
      color_scheme.color_scheme_colors << ColorSchemeColor.new(name: "secondary", hex: "fff")
      resolved = color_scheme.resolved_colors
      expect(resolved["hover"]).to eq("f2f2f2")
      expect(resolved["selected"]).to eq("e9e9e9")
    end
  end

  describe "#diverge_from_remote" do
    fab!(:theme)
    fab!(:original_scheme) do
      Fabricate(
        :color_scheme,
        name: "somescheme",
        theme_id: theme.id,
        user_selectable: true,
        color_scheme_colors: [
          Fabricate(:color_scheme_color, name: "primary", hex: "998877"),
          Fabricate(:color_scheme_color, name: "secondary", hex: "553322"),
        ],
      )
    end

    it "creates a new scheme with the same colors and sets it as the base scheme" do
      expect(original_scheme.base_scheme_id).to eq(nil)

      original_scheme.diverge_from_remote

      expect(original_scheme.base_scheme.colors.map { |c| [c.name, c.hex] }.sort_by(&:first)).to eq(
        original_scheme.colors.map { |c| [c.name, c.hex] }.sort_by(&:first),
      )
      expect(original_scheme.base_scheme.theme.id).to eq(theme.id)
      expect(original_scheme.base_scheme.user_selectable).to eq(false)
      expect(original_scheme.base_scheme.remote_copy).to eq(true)
    end
  end

  describe "#destroy_remote_original" do
    fab!(:theme)

    fab!(:original_scheme) { Fabricate(:color_scheme, name: "somescheme", theme_id: theme.id) }

    fab!(:unrelated_scheme) do
      Fabricate(:color_scheme, theme_id: theme.id, base_scheme_id: original_scheme.id)
    end

    before { original_scheme.diverge_from_remote }

    it "deletes the base scheme that stores the original colors and is triggered on destroy" do
      expect(ColorScheme.unscoped.exists?(id: original_scheme.base_scheme_id)).to eq(true)

      expect do original_scheme.destroy! end.to change { ColorScheme.unscoped.count }.by(-2)

      expect(ColorScheme.unscoped.exists?(id: original_scheme.base_scheme_id)).to eq(false)
    end
  end
end
