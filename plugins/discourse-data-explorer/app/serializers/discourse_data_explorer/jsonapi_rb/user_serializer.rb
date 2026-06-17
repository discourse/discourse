# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # jsonapi-serializer (thin-layers spike). Minimal — exercises the
    # relationship machinery, parity with the Graphiti UserResource.
    class UserSerializer
      include JSONAPI::Serializer
      set_type :users
      attribute :username
    end
  end
end
