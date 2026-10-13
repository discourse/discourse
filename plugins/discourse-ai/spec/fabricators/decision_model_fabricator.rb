# frozen_string_literal: true

Fabricator(:decision_model) do
  display_name "Jev"
  name "jev-latest"
  provider "system_one"
  url "https://api.typesafe.ai/v1/systemone"
  ai_secret
end

Fabricator(:open_ai_decision_model, from: :decision_model) do
  display_name "GPT-6 Luna"
  name "gpt-6-luna"
  provider "open_ai"
  url "https://api.openai.com/v1/decisions"
  vision_enabled true
end
