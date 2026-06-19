# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # jsonapi-serializer (JSON:API Kit). Minimal — exercises the
    # relationship machinery, parity with the Graphiti UserResource.
    class UserSerializer
      include JSONAPI::Serializer
      set_type :users
      attribute :username
      # Enables the nested include `user.groups` (the author's own groups). lazy_load_data
      # so the linkage/association only loads when that path is requested.
      has_many :groups, serializer: GroupSerializer, lazy_load_data: true
    end
  end
end
