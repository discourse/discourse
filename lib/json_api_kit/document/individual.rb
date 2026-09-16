# frozen_string_literal: true

module JsonApiKit
  class Document
    class Individual < Document
      class << self
        def input_class = Request::Input::Individual

        def for(id, parameters, resource:, client:)
          build(parameters, resource:, client:) do
            resource.find(id, it, guardian: client.guardian, default_sorts: client.default_sorts)
          end
        end
      end

      private

      def primary_records = [query.record]

      def data = ResourceObject.new(contents.primary.sole, client:, fieldsets:).to_h
    end
  end
end
