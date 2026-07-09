# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The User resource. Minimal — exercises the relationship machinery for the
    # nested `user.groups` include.
    class UserSerializer
      include JSONAPI::Serializer
      set_type :users
      # Wire attribute replaced `username` (2026-07-01 breaking change): an array of
      # the user's known usernames — currently just the one. Representation-only.
      attribute :usernames do |user|
        [user.username]
      end
      # Enables the nested include `user.groups` (the author's own groups). lazy_load_data
      # so the linkage/association only loads when that path is requested.
      has_many :groups, serializer: GroupSerializer, lazy_load_data: true
    end
  end
end
