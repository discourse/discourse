# frozen_string_literal: true

Fabricator(:permalink) { url { sequence(:url) { |i| "my/#{i}/url" } } }
