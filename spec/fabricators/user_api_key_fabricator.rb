# frozen_string_literal: true

Fabricator(:user_api_key) do
  user

  after_create do |key, transients|
    if key.client.blank?
      client = Fabricate(:user_api_key_client)
      key.user_api_key_client_id = client.id
      key.save!
    end
  end
end

Fabricator(:user_api_key_scope)

Fabricator(:user_api_key_client_scope)

Fabricator(:user_api_key_client) do
  transient :scopes

  client_id { SecureRandom.hex }
  application_name "some app"

  after_create do |client, transients|
    if transients[:scopes].present?
      [*transients[:scopes]].each { |scope| client.scopes.create!(name: scope) }
    end
  end
end

Fabricator(:readonly_user_api_key, from: :user_api_key) do
  scopes { [Fabricate.build(:user_api_key_scope, name: "read")] }
end

Fabricator(:bookmarks_calendar_user_api_key, from: :user_api_key) do
  scopes { [Fabricate.build(:user_api_key_scope, name: "bookmarks_calendar")] }
end
