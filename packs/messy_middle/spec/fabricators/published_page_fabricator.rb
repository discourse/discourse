# frozen_string_literal: true

Fabricator(:published_page) do
  topic
  slug "published-page-test-#{SecureRandom.hex}"
  public false
end
