# frozen_string_literal: true

Fabricator(:calendar_event) do
  user
  username { |attrs| attrs[:user].username }

  topic { |attrs| Fabricate(:topic, user: attrs[:user]) }
  post { |attrs| Fabricate(:post, user: attrs[:user], topic: attrs[:topic]) }

  start_date "2000-01-01"
end
