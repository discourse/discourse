# frozen_string_literal: true
Fabricator(:ai_persona) do
  name { sequence(:name) { |i| "persona_#{i}" } }
  description "I am a test bot"
  system_prompt "You are a test bot"
end
