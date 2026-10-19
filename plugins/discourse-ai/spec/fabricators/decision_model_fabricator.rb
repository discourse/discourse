# frozen_string_literal: true

Fabricator(:decision_model) do
  display_name "TypeSafe Jev"
  name "jev-latest"
  provider "system_one"
  url "https://api.typesafe.ai/v1/systemone"
  ai_secret
end
