# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class ModelStep < Step
      class NotFound < StandardError
      end

      attr_reader :optional

      def initialize(name, method_name = name, class_name: nil, optional: nil)
        super(name, method_name, class_name: class_name)
        @optional = optional.present?
      end

      def run_step
        model = context[name] = super
        raise NotFound if !optional && (!model || model.try(:empty?))

        if model.try(:has_changes_to_save?) && (model.errors.present? || model.invalid?)
          context[result_key].fail(invalid: true)
          context.fail!
        end
      rescue Failure, DefaultValuesNotAllowed
        raise
      rescue => exception
        context[result_key].fail(
          not_found: true,
          exception: (exception unless exception.is_a?(NotFound)),
        )
        context.fail!
      end
    end
  end
end
