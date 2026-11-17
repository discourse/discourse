# frozen_string_literal: true

module JsonApiKit
  class Request
    class Fieldsets
      class Fieldset
        module All
          def self.keep(attributes) = attributes
        end

        class << self
          def parse(raw)
            case raw
            when String
              new(raw.split(LIST, -1))
            when Array
              new(raw.map(&:to_s))
            end
          end
        end

        attr_reader :names

        def initialize(names)
          @names = names
        end

        def keep(attributes) = attributes.select { |name, _value| names.include?(name) }
      end
    end
  end
end
