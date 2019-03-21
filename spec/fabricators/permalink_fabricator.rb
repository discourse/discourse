Fabricator(:permalink) { url { sequence(:url) { |i| "my/#{i}/url" } } }
