# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The User resource. Minimal — exercises the relationship machinery for the
    # nested `user.groups` include.
    class UserResource < ApplicationResource
      type :users
      description "The author of a query."

      # Wire attribute replaced `username` (2026-07-01 breaking change): an array of
      # the user's known usernames — currently just the one. Representation-only.
      attribute :usernames, :array, example: ["query_master"] do |user|
        [user.username]
      end

      # Enables the nested include `user.groups` (the author's own groups).
      has_many :groups, resource: GroupResource
    end
  end
end
