# frozen_string_literal: true

module DiscourseWorkflows
  module Conditions
    module IfCondition
      class V1 < Conditions::Base
        def self.identifier
          "condition:if"
        end

        def self.configuration_schema
          {
            combinator: {
              type: :options,
              options: %w[and or],
              default: "and",
              ui: {
                expression: false,
              },
            },
            conditions: {
              type: :array,
              ui: {
                control: :condition_builder,
              },
            },
            options: {
              caseSensitive: :boolean,
              typeValidation: :string,
              ui: {
                hidden: true,
              },
            },
          }
        end

        attr_reader :condition_details

        def evaluate(input_items:, context: {})
          conditions = @configuration["conditions"] || []
          combinator = @configuration["combinator"] || "and"
          options = @configuration["options"] || {}
          @condition_details = []

          true_items, false_items =
            input_items.partition do |item|
              item_json = item["json"] || {}
              details =
                conditions.map do |condition|
                  evaluate_condition_with_details(condition, item_json, options, context)
                end
              @condition_details.concat(details) if @condition_details.empty?

              results = details.map { |d| d["passed"] }
              combinator == "or" ? results.any? : results.all?
            end

          { "true" => true_items, "false" => false_items }
        end

        private

        def evaluate_condition_with_details(condition, item_json, options, context)
          left = resolve_condition_value(condition["leftValue"], item_json, context)
          operator = condition["operator"] || {}
          type = operator["type"] || "string"
          operation = operator["operation"]
          single_value = operator["singleValue"]
          right =
            (
              if single_value
                nil
              else
                resolve_condition_value(condition["rightValue"], item_json, context)
              end
            )

          passed =
            case type
            when "string"
              evaluate_string(left, right, operation, options)
            when "number", "integer"
              evaluate_number(left, right, operation)
            when "boolean"
              evaluate_boolean(left, right, operation)
            when "array"
              evaluate_array(left, right, operation)
            else
              false
            end

          {
            "left" => left,
            "operator" => operation,
            "right" => right,
            "type" => type,
            "passed" => passed,
          }
        end

        def resolve_condition_value(value, item_json, context)
          if value.is_a?(String) && value.start_with?("=")
            ExpressionResolver.new(context.merge("$json" => item_json)).resolve(value)
          else
            resolve_value(value, item_json)
          end
        end

        def resolve_value(key, data)
          return key unless key.is_a?(String)
          return nil if key.blank?
          keys = key.split(".")
          return key unless data.is_a?(Hash) && data.key?(keys.first)
          keys.reduce(data) { |obj, k| obj.is_a?(Hash) ? obj[k] : nil }
        end

        def evaluate_string(left, right, operation, options)
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
            left.include?(right)
          when "notContains"
            !left.include?(right)
          when "empty"
            left.blank?
          when "notEmpty"
            left.present?
          else
            false
          end
        end

        def evaluate_number(left, right, operation)
          left = left.to_f
          right = right.to_f

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

        def evaluate_array(left, right, operation)
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

        def evaluate_boolean(left, right, operation)
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
      end
    end
  end
end
