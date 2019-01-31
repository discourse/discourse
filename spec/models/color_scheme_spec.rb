require 'rails_helper'

describe ColorScheme do
  after do
    ColorScheme.hex_cache.clear
  end

  let(:valid_params) { { name: "Best Colors Evar", colors: valid_colors } }

  let(:valid_colors) { [
    { name: '$primary_background_color', hex: 'FFBB00' },
    { name: '$secondary_background_color', hex: '888888' }
  ]}

  it "correctly invalidates theme css when changed" do
    scheme = ColorScheme.create_from_base(name: 'Bob')
    theme = Fabricate(:theme, color_scheme_id: scheme.id)
    theme.set_field(name: :scss, target: :desktop, value: '.bob {color: $primary;}')
    theme.save!

    href = Stylesheet::Manager.stylesheet_data(:desktop_theme, theme.id)[0][:new_href]

    ColorSchemeRevisor.revise(scheme, colors: [{ name: 'primary', hex: 'bbb' }])

    href2 = Stylesheet::Manager.stylesheet_data(:desktop_theme, theme.id)[0][:new_href]

    expect(href).not_to eq(href2)
  end

  describe "new" do
    it "can take colors" do
      c = ColorScheme.new(valid_params)
      expect(c.colors.size).to eq valid_colors.size
      expect(c.colors.first).to be_a(ColorSchemeColor)
      expect {
        expect(c.save).to eq true
      }.to change { ColorSchemeColor.count }.by(valid_colors.size)
    end
  end

  describe "create_from_base" do
    let(:base_colors) { { first_one: 'AAAAAA', second_one: '333333', third_one: 'BEEBEE' } }
    let!(:base) { Fabricate(:color_scheme, name: 'Base', color_scheme_colors: [
                    Fabricate(:color_scheme_color, name: 'first_one',  hex: base_colors[:first_one]),
                    Fabricate(:color_scheme_color, name: 'second_one', hex: base_colors[:second_one]),
                    Fabricate(:color_scheme_color, name: 'third_one', hex: base_colors[:third_one])]) }

    before do
      ColorScheme.stubs(:base).returns(base)
    end

    it "creates a new color scheme" do
      c = described_class.create_from_base(name: 'Yellow', colors: { first_one: 'FFFF00', third_one: 'F00D33' })
      expect(c.colors.size).to eq base_colors.size
      first  = c.colors.find { |x| x.name == 'first_one' }
      second = c.colors.find { |x| x.name == 'second_one' }
      third  = c.colors.find { |x| x.name == 'third_one' }
      expect(first.hex).to eq 'FFFF00'
      expect(second.hex).to eq base_colors[:second_one]
      expect(third.hex).to eq 'F00D33'
    end

    context "hex_for_name without anything enabled" do
      before do
        ColorScheme.hex_cache.clear
      end

      it "returns nil for a missing attribute" do
        expect(ColorScheme.hex_for_name('undefined')).to eq nil
      end

      it "returns the base color for an attribute of a specified scheme" do
        scheme = ColorScheme.create_from_base(name: "test scheme")
        ColorSchemeRevisor.revise(scheme, colors: [{ name: "header_background", hex: "9dc927", default_hex: "949493" }])
        scheme.reload
        expect(ColorScheme.hex_for_name("header_background", scheme.id)).to eq("9dc927")
      end

      it "returns the base color for an attribute" do
        expect(ColorScheme.hex_for_name('second_one')).to eq base_colors[:second_one]
      end
    end
  end
end
