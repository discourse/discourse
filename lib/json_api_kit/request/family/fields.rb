# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Fields < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.to_h do |fieldset_type, fields|
            [
              fieldset_type,
              names(fields, path + [fieldset_type]) do
                Name::Field.new(value: it, type: fieldset_type)
              end,
            ]
          end
        end
      end
    end
  end
end
