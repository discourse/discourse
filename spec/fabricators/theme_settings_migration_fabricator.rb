# frozen_string_literal: true

Fabricator(:theme_settings_migration) do
  theme
  theme_field
  version { |attrs| sequence("theme_#{attrs[:theme].id}_migrations", 1) }
  name { |attrs| "migration-n-#{attrs[:version]}" }
  diff { { "additions" => [], "deletions" => [] } }
end
