# frozen_string_literal: true

Fabricator(:theme) do
  name { sequence(:name) { |i| "Cool theme #{i + 1}" } }
  user
end

Fabricator(:remote_theme) { remote_url { "https://github.com/org/testtheme.git" } }

Fabricator(:theme_with_remote_url, from: :theme) { remote_theme }
