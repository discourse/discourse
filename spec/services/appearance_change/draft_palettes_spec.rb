# frozen_string_literal: true

RSpec.describe AppearanceChange::DraftPalettes do
  let(:light_colors) do
    {
      "primary" => "222222",
      "secondary" => "ffffff",
      "tertiary" => "0060df",
      "quaternary" => "e45735",
      "header_background" => "0a2540",
      "header_primary" => "ffffff",
      "highlight" => "ffff4d",
      "selected" => "d1f0ff",
      "hover" => "f2f2f2",
      "danger" => "c80001",
      "success" => "009900",
      "love" => "fa6c8d",
    }
  end
  let(:dark_colors) { ColorScheme::BUILT_IN_SCHEMES[:Dark] }

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(**attributes) }

    let(:attributes) { { name: "Acme", theme_id: 1, light_colors:, dark_colors: } }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:light_colors) }
    it { is_expected.to validate_presence_of(:dark_colors) }

    it "requires every palette colour as a six-digit hex value" do
      attributes[:light_colors] = light_colors.merge("primary" => "#222")
      attributes[:dark_colors] = dark_colors.except("love")

      expect(contract).not_to be_valid
      expect(contract.errors.attribute_names).to include(
        :"light_colors.primary",
        :"dark_colors.love",
      )
    end

    it "only accepts fonts that are available" do
      attributes[:site_settings] = { base_font: "not-a-font", heading_font: "roboto" }

      expect(contract).not_to be_valid
      expect(contract.errors.attribute_names).to contain_exactly(:"site_settings.base_font")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:theme)

    let(:params) do
      {
        theme_id: theme.id,
        name: "Acme",
        light_colors:,
        dark_colors:,
        site_settings: {
          base_font: "roboto",
        },
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when data is invalid" do
      let(:params) { { theme_id: theme.id, name: "", light_colors:, dark_colors: } }

      it { is_expected.to fail_a_contract }
    end

    context "when the theme is a component" do
      fab!(:component) { Fabricate(:theme, component: true) }

      let(:params) { super().merge(theme_id: component.id) }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when the user can't edit the theme" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_edit_theme) }
    end

    context "when a plugin restricts palette creation" do
      let(:plugin) { Plugin::Instance.new }
      let(:modifier) { proc { false } }

      before { plugin.register_modifier(:user_guardian_can_create_color_scheme, &modifier) }

      after do
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :user_guardian_can_create_color_scheme,
          &modifier
        )
      end

      it { is_expected.to fail_a_policy(:can_create_color_scheme) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the palettes without giving them to the theme" do
        appearance_change = result[:appearance_change]

        expect(appearance_change.light_color_scheme).to have_attributes(
          name: "Acme",
          user_selectable: false,
        )
        expect(appearance_change.light_color_scheme.colors.to_h { [it.name, it.hex] }).to eq(
          light_colors,
        )
        expect(appearance_change.dark_color_scheme.name).to eq("Acme Dark")
        expect(appearance_change.dark_color_scheme.colors.to_h { [it.name, it.hex] }).to eq(
          dark_colors,
        )
        expect(theme.reload).to have_attributes(color_scheme_id: nil, dark_color_scheme_id: nil)
      end

      it "records a draft with the fonts to apply once it is live" do
        expect(result[:appearance_change]).to have_attributes(
          kind: "palettes",
          name: "Acme",
          theme:,
          user: acting_user,
          site_settings: {
            "base_font" => "roboto",
          },
          draft?: true,
        )
      end
    end
  end
end
