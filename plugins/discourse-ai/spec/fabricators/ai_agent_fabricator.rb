# frozen_string_literal: true
Fabricator(:ai_agent) do
  name { sequence(:name) { |i| "agent_#{i}" } }
  description "I am a test bot"
  system_prompt "You are a test bot"
  show_thinking false
end
