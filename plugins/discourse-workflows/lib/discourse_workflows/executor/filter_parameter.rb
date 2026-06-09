# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module FilterParameter
      def self.execute_filter(conditions, combinator, options, resolver)
        details = conditions.map { |c| execute_filter_condition(c, options, resolver) }
        passed =
          if combinator == "or"
            details.any? { |d| d["passed"] }
          else
            details.all? { |d| d["passed"] }
          end

        { "passed" => passed, "details" => details }
      end

      def self.execute_filter_condition(condition, options, resolver)
        left_expression = condition["leftValue"]
        left = resolver.resolve(left_expression)
        operator = condition.fetch("operator") { {} }
        type = operator.fetch("type") { "string" }
        operation = operator["operation"]
        right = resolver.resolve(condition["rightValue"]) unless operator["singleValue"]
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
