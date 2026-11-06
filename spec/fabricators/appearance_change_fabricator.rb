# frozen_string_literal: true

Fabricator(:appearance_change) do
  kind :palettes
  name { sequence(:name) { |i| "Appearance #{i}" } }
  light_color_scheme(fabricator: :color_scheme)
  dark_color_scheme(fabricator: :color_scheme)
  theme
  user
end

Fabricator(:theme_appearance_change, from: :appearance_change) do
  kind :theme
  theme do |attrs|
    Fabricate(
      :theme,
      color_scheme: attrs[:light_color_scheme],
      dark_color_scheme: attrs[:dark_color_scheme],
    )
  end
end
