# frozen_string_literal: true

RSpec.describe Admin::Config::ColorPalettesController do
  fab!(:admin)
  fab!(:theme)

  before { sign_in(admin) }

  fab!(:palette_1) do
    Fabricate(:color_scheme, user_selectable: false, theme_id: nil, name: "A palette")
  end

  fab!(:palette_2) do
    Fabricate(:color_scheme, user_selectable: false, theme_id: nil, name: "B palette")
  end

  fab!(:user_selectable_palette) { Fabricate(:color_scheme, user_selectable: true, theme_id: nil) }

  fab!(:user_selectable_theme_palette) do
    Fabricate(:color_scheme, user_selectable: true, theme_id: theme.id)
  end

  fab!(:user_selectable_default_theme_palette) do
    Fabricate(:color_scheme, user_selectable: true, theme_id: Theme.find_default.id)
  end

  describe "#index" do
    before do
      ColorScheme.where(theme_id: Theme.horizon_theme.id).destroy_all
      ColorScheme.where(via_wizard: true).destroy_all
    end

    it "sorts non-base palettes in a certain way" do
      get "/admin/config/colors.json"

      expect(response.status).to eq(200)

      non_base_palettes = response.parsed_body["palettes"].select { |palette| !palette["is_base"] }
      expect(non_base_palettes.size).to eq(5)
      expect(non_base_palettes.map { |p| p["id"] }).to eq(
        [
          user_selectable_palette.id,
          user_selectable_default_theme_palette.id,
          user_selectable_theme_palette.id,
          palette_1.id,
          palette_2.id,
        ],
      )
    end

    it "includes base palettes at the start" do
      get "/admin/config/colors.json"

      expect(response.status).to eq(200)

      base_palettes = response.parsed_body["palettes"].select { |palette| palette["is_base"] }
      expect(base_palettes.size).to be > 0
      expect(response.parsed_body["palettes"].first).to eq(base_palettes.first)
    end

    it "includes default theme in extras" do
      get "/admin/config/colors.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["extras"]["default_theme"]).to be_present
      expect(response.parsed_body["extras"]["default_theme"]["id"]).to eq(Theme.find_default.id)
    end
  end
end
