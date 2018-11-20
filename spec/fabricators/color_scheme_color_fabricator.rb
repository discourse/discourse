Fabricator(:color_scheme_color) do
  color_scheme
  name { sequence(:name) { |i| "color_#{i}" } }
  hex "333333"
end
