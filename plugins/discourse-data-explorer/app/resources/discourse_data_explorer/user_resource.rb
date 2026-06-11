# frozen_string_literal: true

module DiscourseDataExplorer
  # Deliberately minimal — exists to exercise the relationship machinery,
  # not to model User fully.
  class UserResource < ApplicationResource
    self.model = ::User
    self.type = :users

    attribute :username, :string
  end
end
