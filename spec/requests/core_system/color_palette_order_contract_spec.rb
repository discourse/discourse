# frozen_string_literal: true
RSpec.describe Admin::Config::ColorPalettesController do
  fab!(:admin) { Fabricate(:admin, locale: "en") }

  let(:foundation_scheme_a) do
    Fabricate(:color_scheme, name: "Foundation scheme a", theme: Theme.foundation_theme)
  end
  let(:foundation_scheme_b) do
    Fabricate(:color_scheme, name: "Foundation scheme b", theme: Theme.foundation_theme)
  end
  let(:horizon_scheme_a) do
    Fabricate(:color_scheme, name: "Horizon scheme a", theme: Theme.horizon_theme)
  end
  let(:horizon_scheme_b) do
    Fabricate(:color_scheme, name: "Horizon scheme b", theme: Theme.horizon_theme)
  end
  let(:custom_scheme_a) { Fabricate(:color_scheme, name: "Custom scheme a") }
  let(:custom_scheme_b) { Fabricate(:color_scheme, name: "Custom scheme b") }
  let(:selectable_foundation_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme a",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_foundation_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme b",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme a",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme b",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_custom_scheme_a) do
    Fabricate(:color_scheme, name: "Selectable custom scheme a", user_selectable: true)
  end
  let(:selectable_custom_scheme_b) do
    Fabricate(:color_scheme, name: "Selectable custom scheme b", user_selectable: true)
  end
  let(:default_light_scheme) { Fabricate(:color_scheme, name: "Default light") }
  let(:default_dark_scheme) { Fabricate(:color_scheme, name: "Default dark") }

  before { sign_in(admin) }

  describe "#index" do
    it "orders Horizon default, selectable, custom, and theme palettes in the public response" do
      ColorScheme.delete_all
      foundation_scheme_a
      foundation_scheme_b
      horizon_scheme_a
      horizon_scheme_b
      custom_scheme_a
      custom_scheme_b
      selectable_foundation_scheme_a
      selectable_foundation_scheme_b
      selectable_horizon_theme_scheme_a
      selectable_horizon_theme_scheme_b
      selectable_custom_scheme_a
      selectable_custom_scheme_b
      default_light_scheme
      default_dark_scheme
      Theme.horizon_theme.update!(
        color_scheme: default_light_scheme,
        dark_color_scheme: default_dark_scheme,
      )
      SiteSetting.default_theme_id = Theme.horizon_theme.id

      get "/admin/config/colors.json"
      expect(response.status).to eq(200)

      palettes = response.parsed_body.fetch("palettes")
      displayed_palettes =
        palettes.select { |palette| !palette["is_base"] || palette["is_builtin_default"] }
      expected_palettes = [
        default_light_scheme,
        default_dark_scheme,
        selectable_custom_scheme_a,
        selectable_custom_scheme_b,
        selectable_horizon_theme_scheme_a,
        selectable_horizon_theme_scheme_b,
        selectable_foundation_scheme_a,
        selectable_foundation_scheme_b,
        custom_scheme_a,
        custom_scheme_b,
        horizon_scheme_a,
        horizon_scheme_b,
        foundation_scheme_a,
        foundation_scheme_b,
      ]

      aggregate_failures("ordered visible palette identities and labels") do
        expect(displayed_palettes.map { |palette| palette.fetch("id") }).to eq(
          [*expected_palettes.map(&:id), -1],
        )
        expect(displayed_palettes.map { |palette| palette.fetch("name") }).to eq(
          [
            "Default light",
            "Default dark",
            "Selectable custom scheme a",
            "Selectable custom scheme b",
            "Selectable horizon scheme a",
            "Selectable horizon scheme b",
            "Selectable foundation scheme a",
            "Selectable foundation scheme b",
            "Custom scheme a",
            "Custom scheme b",
            "Horizon scheme a",
            "Horizon scheme b",
            "Foundation scheme a",
            "Foundation scheme b",
            I18n.t("admin_js.admin.customize.theme.default_light_scheme"),
          ],
        )
        expect(displayed_palettes.map { |palette| palette.fetch("id") }.uniq.length).to eq(15)
        expect(displayed_palettes.last).to include(
          "id" => -1,
          "is_base" => true,
          "is_builtin_default" => true,
          "name" => I18n.t("admin_js.admin.customize.theme.default_light_scheme"),
        )
      end

      hidden_base_palettes =
        palettes.select { |palette| palette["is_base"] && !palette["is_builtin_default"] }
      expect(hidden_base_palettes.map { |palette| palette.fetch("id") }).to contain_exactly(
        *ColorScheme::NAMES_TO_ID_MAP.values.reject { |id| id == -1 },
      )
    end
  end
end
