# frozen_string_literal: true

Fabricator(:ai_mcp_server) do
  name { sequence(:name) { |n| "MCP Server #{n}" } }
  description "External MCP server"
  url { sequence(:url) { |n| "https://mcp#{n}.example.com" } }
  auth_header "Authorization"
  auth_scheme "Bearer"
  enabled true
  timeout_seconds 30
end
