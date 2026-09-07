# frozen_string_literal: true

module JsonApiKit
  class Glossary
    module CasingRule
      CAMEL_BOUNDARY = /(?<before>[a-z\d])(?<capital>[A-Z])/
      SNAKE_BOUNDARY = /_(?<letter>[a-z\d])/
      MEMBER_NAMES = Hash.new { |cache, name| cache[name] = camel_case(name) }

      class << self
        def declared_attributes(attributes) = attributes.transform_keys { declared_name(it) }

        def declared_name(name)
          snake_case(name).tap { raise Correction.new(it) unless camel_case(it) == name }
        end

        def member_name(name) = camel_case(name)

        def member_attributes(attributes) = attributes.transform_keys { MEMBER_NAMES[it] }

        private

        def snake_case(name)
          name.convert { it.gsub(CAMEL_BOUNDARY, '\k<before>_\k<capital>').downcase }
        end

        def camel_case(name)
          name.convert { it.gsub(SNAKE_BOUNDARY) { Regexp.last_match[:letter].upcase } }
        end
      end
    end
  end
end
