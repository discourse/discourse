# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Declarations
        class Anchor
          class NoRow < BadRequest
            def initialize(name, value)
              @name = name
              super("No record matches anchor #{name}=#{value.inspect}.")
            end

            def title = "No record matches the anchor"

            def source = { parameter: "page[anchor][#{name}]" }

            private

            attr_reader :name
          end

          IDENTITY = "id"

          class << self
            def for(name, &condition)
              return Computed.new(name, &condition) if condition
              return Identity.new(name) if name.to_s == IDENTITY
              Attribute.new(name)
            end
          end

          attr_reader :name

          def initialize(name)
            @name = name.to_s
          end
        end
      end
    end
  end
end
