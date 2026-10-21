# frozen_string_literal: true

class UserResource < JsonApiKit::Resource
  attribute :username
  attribute :avatar_template, columns: %i[username uploaded_avatar_id]
end
