# frozen_string_literal: true

module JsonApiKit
  class Glossary
    module CasingRule
      CAMEL_BOUNDARY = /(?<before>[a-z\d])(?<capital>[A-Z])/
      SNAKE_BOUNDARY = /_(?<letter>[a-z\d])/

      class NotAMemberName < BadRequest
        attr_reader :raw, :member

        def initialize(raw, member, parameter: nil)
          @raw = raw
          @member = member
          @parameter = parameter
          super("Use #{member}, not #{raw}.")
        end

        def title = "Invalid member name"

        def source = { parameter: @parameter }.compact

        def at(parameter) = self.class.new(raw, member, parameter:)
      end

      class << self
        def declared_name(raw)
          name = raw.to_s.gsub(CAMEL_BOUNDARY, '\k<before>_\k<capital>').downcase
          member = member_name(name)
          raise NotAMemberName.new(raw, member) unless member == raw.to_s
          name
        end

        def member_name(name)
          name.to_s.gsub(SNAKE_BOUNDARY) { Regexp.last_match[:letter].upcase }
        end
      end
    end
  end
end
