# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Fields < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.to_h { |type, raw| [type, declared_fieldset(raw, type, path + [type])] }
        end

        private

        def declared_fieldset(raw, type, path)
          Fieldsets::Fieldset
            .parse(raw)
            .try do |fieldset|
              fieldset.names.map { declared_name(Name::Field.new(value: it, type:), path) }
            end || raw
        end
      end
    end
  end
end
