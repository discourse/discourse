# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Fields < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.to_h do |type, raw|
            [declared_type(type, path), declared_fieldset(raw, type, path + [type])]
          end
        end

        private

        def declared_type(type, path)
          declared_name(Name::Type.new(value: type), path + [type])
        end

        def declared_fieldset(raw, type, path)
          Fieldsets::Fieldset
            .parse(raw)
            .try do |fieldset|
              fieldset
                .names
                .flat_map { declared_names(Name::Field.new(value: it, type:), path) }
                .uniq
            end || raw
        end
      end
    end
  end
end
