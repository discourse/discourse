# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Filter < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.transform_keys { declared_name(Name::Filter.new(value: it, type:), path + [it]) }
        end
      end
    end
  end
end
