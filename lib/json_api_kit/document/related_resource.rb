# frozen_string_literal: true

module JsonApiKit
  class Document
    class RelatedResource < Document
      class << self
        def input_class = Request::Input::RelatedResource

        def for(parameters, resource:, client:, scoped_to:)
          build(parameters, resource:, client:) do |params, instance|
            instance.all(params, scoped_to:)
          end
        end
      end

      delegate :primary_record, to: :contents, private: true

      private

      def primary_records
        return [] if query.records.empty?
        [query.records.sole]
      end

      def data = primary_record.try { representation(it).to_h }

      def representation(record) = ResourceObject.new(record, client:, fieldsets:)
    end
  end
end
