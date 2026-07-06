# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    class GroupSerializer
      include JSONAPI::Serializer
      set_type :groups
      attribute :name
    end
  end
end
