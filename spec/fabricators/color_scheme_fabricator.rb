Fabricator(:color_scheme) do
  name { sequence(:name) {|i| "Palette #{i}" } }
  enabled false
  color_scheme_colors(count: 2) { |attrs, i| Fabricate.build(:color_scheme_color, color_scheme: nil) }
end
