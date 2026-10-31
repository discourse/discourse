# frozen_string_literal: true

module DiscourseDataExplorer
  module Adapters
    class CachedResults
      class Definition < JsonApiKit::Adapter::Definition
        def self.required_owner_fields(_name, owner_resource:) = [:sql]
      end
    end
  end
end
