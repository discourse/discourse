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
          parent.value[path.last] if parent.object?
        end

        def supplied? = root? || (parent.object? && parent.value.key?(path.last))

        def object? = value.is_a?(Hash)

        def string? = value.is_a?(String)

        def name = root? ? "The document" : path.last

        def nearest_existing
          return self if supplied?
          parent.nearest_existing
        end

        def pointer = path.map { "/#{it.gsub("~", "~0").gsub("/", "~1")}" }.join

        private

        attr_reader :document, :path

        def root? = path.empty?

        def parent = @parent ||= self.class.new(document, path[...-1])
      end
    end
  end
end
