# frozen_string_literal: true

module JsonApiKit
  class Request
    class Filters
      include Enumerable

      def initialize(parameters, resource:)
        @parameters = parameters.symbolize_keys
        @resource = resource
      end

      def each(&block)
        return enum_for(:each) unless block

        each_local_filter(&block)
        each_related_filter(&block)
        self
      end

      private

      attr_reader :parameters, :resource

      def each_local_filter
        parameters.fetch(:filter, {}).each { |name, value| yield [local_path(name), value] }
      end

      def local_path(name)
        Name::FilterPath.new(
          relationships: [],
          filter: Name::Filter.new(value: name, type: resource.type),
        )
      end

      def each_related_filter(&block)
        parameters
          .fetch(:forwarded_filters, {})
          .each { |name, forwarded| each_filter_for(name, forwarded, &block) }
      end

      def each_filter_for(name, forwarded)
        Name::Relationship
          .new(value: name, type: resource.type)
          .then do |relationship|
            self
              .class
              .new(forwarded, resource: resource.related_resource(name))
              .each { |path, value| yield [path.prepend(relationship), value] }
          end
      end
    end
  end
end
