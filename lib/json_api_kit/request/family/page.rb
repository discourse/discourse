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

        def anchor(value, path) = names(value, path) { Name::Anchor.new(value: it, type:) }
      end
    end
  end
end
