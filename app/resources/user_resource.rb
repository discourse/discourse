# frozen_string_literal: true

class UserResource < JsonApiKit::Resource
  attribute :username
  attribute :avatar_template
end
