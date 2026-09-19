# frozen_string_literal: true

module JsonApiKit
  class Document
    class Individual < Document
      class << self
        def input_class = Request::Input::Individual

        def for(id, parameters, resource:, client:)
          build(parameters, resource:, client:) { |params, instance| instance.find(id, params) }
        end
      end

      private

      def primary_records = [query.record]

      def data = ResourceObject.new(contents.primary.sole, client:, fieldsets:).to_h
    end
  end
end
