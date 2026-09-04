# frozen_string_literal: true

Fabricator(:published_page) do
  topic
  slug "published-page-test-#{SecureRandom.hex}"
  # rubocop:disable Style/AccessModifierDeclarations
  public false
  # rubocop:enable Style/AccessModifierDeclarations
end
