# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Location
        def self.for(attribute, document:)
          new(document, attribute == :base ? [] : attribute.to_s.split("."))
        end

        def initialize(document, path)
          @document = document
          @path = path
        end

        def value
          return document if root?
          parent.value.then { |container| container[path.last] if member_of?(container) }
        end

        def supplied? = root? || member_of?(parent.value)

        def object? = value.is_a?(Hash)

        def string? = value.is_a?(String)

        def child(*members) = self.class.new(document, path + members)

        def name = root? ? "The document" : path.last

        def nearest_existing
          return self if supplied?
          parent.nearest_existing
        end

        def pointer = path.map { "/#{it.to_s.gsub("~", "~0").gsub("/", "~1")}" }.join

        private

        attr_reader :document, :path

        def root? = path.empty?

        def parent = @parent ||= self.class.new(document, path[...-1])

        def member_of?(container)
          case container
          when Hash
            container.key?(path.last)
          when Array
            path.last.is_a?(Integer) && path.last.between?(0, container.size - 1)
          else
            false
          end
        end
      end
    end
  end
end
