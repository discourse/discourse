# frozen_string_literal: true

Fabricator(:ai_tool) do
  name "github tool"
  tool_name "github_tool"
  description "This is a tool for GitHub"
  summary "This is a tool for GitHub"
  script "puts 'Hello, GitHub!'"
  created_by_id 1
end
