# frozen_string_literal: true

Fabricator(:ai_secret) do
  name { sequence(:name) { |n| "API Secret #{n}" } }
  secret "sk-test-secret-key-123"
end
