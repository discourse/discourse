# frozen_string_literal: true

module JsonApiKit
  class Glossary
    module CasingRule
      CAMEL_BOUNDARY = /(?<before>[a-z\d])(?<capital>[A-Z])/
      SNAKE_BOUNDARY = /_(?<letter>[a-z\d])/

      class << self
        def declared_name(name)
          snake_case(name).tap { raise Correction.new(it) unless member_name(it) == name }
        end

        def member_name(name)
          name.convert { it.gsub(SNAKE_BOUNDARY) { Regexp.last_match[:letter].upcase } }
        end

        private

        def snake_case(name)
          name.convert { it.gsub(CAMEL_BOUNDARY, '\k<before>_\k<capital>').downcase }
        end
      end
    end
  end
end
