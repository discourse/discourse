# frozen_string_literal: true

Fabricator(:permalink) do
  url { sequence(:url) { |i| "my/#{i}/url" } }
end
