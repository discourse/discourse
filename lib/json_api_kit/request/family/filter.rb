# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Filter < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.transform_keys { declared_name(filter_name(it), path + [it]) }
        end

        private

        def filter_name(value) =
          Name::Filter.new(value:, type:, collection: resource.collection_name)
      end
    end
  end
end
