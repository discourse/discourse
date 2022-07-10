# frozen_string_literal: true

class UserStatusSerializer < ApplicationSerializer
  attributes :description, :emoji, :ends_at
end
