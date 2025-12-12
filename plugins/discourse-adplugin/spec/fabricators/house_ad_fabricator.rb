# frozen_string_literal: true

Fabricator(:house_ad, from: AdPlugin::HouseAd) do
  name { sequence(:name) { |i| "Find A Mechanic #{i}" } }
  html '<div class="house-ad find-a-mechanic"><a href="https://mechanics.example.com">Find A Mechanic!</a></div>'
end
