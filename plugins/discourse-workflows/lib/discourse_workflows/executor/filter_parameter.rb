# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module FilterParameter
      OPERATION_DEFINITIONS = {
        "equals" => { types: %w[string number boolean].freeze, needs_value: true }.freeze,
        "notEquals" => { types: %w[string number boolean].freeze, needs_value: true }.freeze,
        "contains" => { types: %w[string array].freeze, needs_value: true }.freeze,
        "notContains" => { types: %w[string array].freeze, needs_value: true }.freeze,
        "empty" => { types: %w[string array].freeze, needs_value: false }.freeze,
        "notEmpty" => { types: %w[string array].freeze, needs_value: false }.freeze,
        "gt" => { types: %w[number].freeze, needs_value: true }.freeze,
        "lt" => { types: %w[number].freeze, needs_value: true }.freeze,
        "gte" => { types: %w[number].freeze, needs_value: true }.freeze,
        "lte" => { types: %w[number].freeze, needs_value: true }.freeze,
        "true" => { types: %w[boolean].freeze, needs_value: false }.freeze,
        "false" => { types: %w[boolean].freeze, needs_value: false }.freeze,
      }.freeze
      def self.supported_types
        OPERATION_DEFINITIONS.values.flat_map { |definition| definition.fetch(:types) }.uniq
      end

      def self.supported_operations(type)
        OPERATION_DEFINITIONS.filter_map do |operation, definition|
          operation if definition.fetch(:types).include?(type.to_s)
        end
      end

      def self.supported_operation?(type, operation)
        OPERATION_DEFINITIONS.fetch(operation.to_s, {}).fetch(:types, []).include?(type.to_s)
      end

      def self.operation_needs_value?(operation)
        OPERATION_DEFINITIONS.dig(operation.to_s, :needs_value)
      end

      def self.execute_filter(conditions, combinator, options, resolver)
        details =
          conditions.map { |condition| execute_filter_condition(condition, options, resolver) }
        passed =
          if combinator == "or"
            details.any? { |detail| detail["passed"] }
          else
            details.all? { |detail| detail["passed"] }
          end

        { "passed" => passed, "details" => details }
      end

      def self.execute_filter_condition(condition, options, resolver)
        left_expression = condition["leftValue"]
        left = resolver.resolve(left_expression)
        operator = condition.fetch("operator") { {} }
        type = operator.fetch("type") { "string" }
        operation = operator["operation"]
        right = resolver.resolve(condition["rightValue"]) if operation_needs_value?(operation)
        passed = evaluate_type(type, left, right, operation, options)

        {
          "left" => left,
          "leftExpression" => left_expression,
          "operator" => operation,
          "right" => right,
          "type" => type,
          "passed" => passed,
        }
      end

      def self.evaluate_type(type, left, right, operation, options)
        return false unless supported_operation?(type, operation)

        case type
        when "string"
          evaluate_string(left, right, operation, options)
        when "number"
          evaluate_number(left, right, operation)
        when "boolean"
          evaluate_boolean(left, right, operation)
        when "array"
          evaluate_array(left, right, operation)
        else
          false
        end
      end

      def self.evaluate_string(left, right, operation, options)
        case_sensitive = options.fetch("caseSensitive", true)
        left = left.to_s
        right = right.to_s unless right.nil?

        unless case_sensitive
          left = left.downcase
          right = right&.downcase
        end

        case operation
        when "equals"
          left == right
        when "notEquals"
          left != right
        when "contains"
          right.present? && left.include?(right)
        when "notContains"
          right.blank? || !left.include?(right)
        when "empty"
          left.blank?
        when "notEmpty"
          left.present?
        else
          false
        end
      end

      def self.evaluate_number(left, right, operation)
        left = coerce_number(left)
        right = coerce_number(right)
        return false if left.nil? || right.nil?

        compare_values(left, right, operation)
      end

      def self.evaluate_boolean(left, right, operation)
        case operation
        when "true"
          left == true
        when "false"
          left == false
        when "equals"
          left == right
        when "notEquals"
          left != right
        else
          false
        end
      end

      def self.evaluate_array(left, right, operation)
        case operation
        when "contains"
          Array.wrap(left).include?(right)
        when "notContains"
          !Array.wrap(left).include?(right)
        when "empty"
          return false if left.nil?
          Array.wrap(left).empty?
        when "notEmpty"
          Array.wrap(left).present?
        else
          false
        end
      end

      def self.compare_values(left, right, operation)
        case operation
        when "equals"
          left == right
        when "notEquals"
          left != right
        when "gt"
          left > right
        when "lt"
          left < right
        when "gte"
          left >= right
        when "lte"
          left <= right
        else
          false
        end
      end

      def self.coerce_number(value)
        Float(value)
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :coerce_number
    end
  end
end
