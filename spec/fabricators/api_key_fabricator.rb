# frozen_string_literal: true

Fabricator(:api_key)

Fabricator(:global_api_key, from: :api_key)

Fabricator(:read_only_api_key, from: :api_key) do
  api_key_scopes(count: 1) do |attrs, i|
    Fabricate.build(:api_key_scope, resource: "global", action: "read")
  end
end

Fabricator(:granular_api_key, from: :api_key) do
  api_key_scopes(count: 1) do |attrs, i|
    Fabricate.build(:api_key_scope, resource: "topics", action: "read")
    Fabricate.build(:api_key_scope, resource: "topics", action: "write")
  end
end
