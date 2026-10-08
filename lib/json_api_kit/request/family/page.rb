# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Page < Family
        ANCHOR = "anchor"

        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.to_h do |member, member_value|
            key = declared_name(Name::Member.new(value: member), path + [member])
            [key, key == ANCHOR ? anchor(member_value, path + [key]) : member_value]
          end
        end

        private

        def anchor(value, path)
          return names(value, path) { anchor_name(it) } unless value.is_a?(Hash)
          declared_anchor(value, path)
        end

        def declared_anchor(value, path)
          glossary.declared_attributes(anchor_attributes(value)).transform_keys(&:value)
        rescue Glossary::NotAMemberName => error
          raise error.at(ParameterName.new(*path, error.raw.value).to_s)
        rescue Glossary::BadValue => error
          raise error.at(ParameterName.new(*path).to_s)
        end

        def anchor_attributes(value) = value.transform_keys { anchor_name(it) }

        def anchor_name(value) = Name::Anchor.new(value:, type:)
      end
    end
  end
end
