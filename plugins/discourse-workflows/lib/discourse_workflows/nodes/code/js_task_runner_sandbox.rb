# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Code
      class JsTaskRunnerSandbox
        include NodeErrorHandling

        RUN_CODE = "runCode"
        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"
        JS_TEXT_KEYS = { object: { singular: "object", plural: "objects" } }.freeze
        RESERVED_ITEM_KEYS = %w[json pairedItem error index].freeze

        def initialize(
          workflow_mode,
          execute_functions,
          chunk_size = 1000,
          additional_properties = {}
        )
          @workflow_mode = workflow_mode
          @execute_functions = execute_functions
          @chunk_size = chunk_size || 1000
          @additional_properties = additional_properties || {}
        end

        def run_code_all_items(code)
          execution_result =
            @execute_functions.start_job(
              "javascript",
              {
                code: code,
                nodeMode: RUN_ONCE_FOR_ALL_ITEMS,
                workflowMode: @workflow_mode,
                continueOnFail: @execute_functions.continue_on_fail,
                additionalProperties: @additional_properties,
              },
              0,
            )
          raise_execution_error!(execution_result) unless execution_result.ok

          result = execution_result.result
          return [] if result.nil?

          validate_run_code_all_items(result)
        end

        def run_code_for_tool(code)
          execution_result =
            @execute_functions.start_job(
              "javascript",
              {
                code: code,
                nodeMode: RUN_ONCE_FOR_ALL_ITEMS,
                workflowMode: @workflow_mode,
                continueOnFail: @execute_functions.continue_on_fail,
                additionalProperties: @additional_properties,
              },
              0,
            )
          raise_execution_error!(execution_result) unless execution_result.ok

          execution_result.result
        end

        def run_code_for_each_item(code, num_input_items)
          validate_no_disallowed_methods_in_run_for_each(code, 0)

          chunk_input_items(num_input_items).flat_map do |chunk|
            execution_result =
              @execute_functions.start_job(
                "javascript",
                {
                  code: code,
                  nodeMode: RUN_ONCE_FOR_EACH_ITEM,
                  workflowMode: @workflow_mode,
                  continueOnFail: @execute_functions.continue_on_fail,
                  chunk: {
                    startIndex: chunk[:start_index],
                    count: chunk[:count],
                  },
                  additionalProperties: @additional_properties,
                },
                0,
              )
            raise_execution_error!(execution_result) unless execution_result.ok

            execution_result.result.map.with_index do |result, index|
              validate_run_code_each_item(result, item_index: chunk[:start_index] + index)
            end
          end
        end

        def run_code(code)
          execution_result =
            @execute_functions.start_job(
              "javascript",
              {
                code: code,
                nodeMode: RUN_CODE,
                workflowMode: @workflow_mode,
                continueOnFail: @execute_functions.continue_on_fail,
                additionalProperties: @additional_properties,
              },
              0,
            )
          raise_execution_error!(execution_result) unless execution_result.ok

          execution_result.result
        end

        private

        def chunk_input_items(num_input_items)
          num_chunks = (num_input_items.to_f / @chunk_size).ceil
          Array.new(num_chunks) do |index|
            start_index = index * @chunk_size
            count = index == num_chunks - 1 ? num_input_items - start_index : @chunk_size
            { start_index: start_index, count: count }
          end
        end

        def raise_execution_error!(execution_result)
          error = execution_result.error
          raise error if error.is_a?(Exception)

          raise_node_error!(
            I18n.t("discourse_workflows.errors.javascript_execution_failed"),
            description: error.to_s,
          )
        end

        def validate_no_disallowed_methods_in_run_for_each(code, item_index)
          match = code.match(/\$input\.(?<disallowed_method>first|last|all|itemMatching)/)
          return if match.blank?

          disallowed_method = match[:disallowed_method]
          line_number =
            code
              .split("\n")
              .find_index do |line|
                stripped = line.strip
                line.include?(disallowed_method) && !stripped.start_with?("//", "/*", "*")
              end
          return if line_number.nil?

          raise_node_error!(
            "Can't use .#{disallowed_method}() here",
            description: "This is only available in 'Run Once for All Items' mode.",
            item_index: item_index,
            line_number: line_number + 1,
          )
        end

        def validate_run_code_each_item(value, item_index:)
          unless value.is_a?(Hash) || value.is_a?(Array)
            raise_node_error!(
              "Code doesn't return #{text_key(:object, include_article: true)}",
              description:
                "Please return #{text_key(:object, include_article: true)} representing the output " \
                  "item. ('#{value}' was returned instead.)",
              item_index: item_index,
            )
          end

          if value.is_a?(Array)
            first_sentence =
              if value.length > 0
                "An array of #{value.first.class.name.downcase}s was returned."
              else
                "An empty array was returned."
              end
            raise_node_error!(
              "Code doesn't return a single #{text_key(:object)}",
              description:
                "#{first_sentence} If you need to output multiple items, please use the " \
                  "'Run Once for All Items' mode instead.",
              item_index: item_index,
            )
          end

          return_data = normalize_items!([value]).first
          validate_item!(return_data, item_index: item_index)
          validate_top_level_keys!(return_data, item_index: item_index)
          return_data["pairedItem"] ||= { "item" => item_index }
          return_data
        end

        def validate_run_code_all_items(value)
          unless value.is_a?(Hash) || value.is_a?(Array)
            raise_node_error!(
              "Code doesn't return items properly",
              description:
                "Please return an array of #{text_key(:object, plural: true)}, one for each item " \
                  "you would like to output.",
            )
          end

          if value.is_a?(Array)
            unless value.all? { |item| item.is_a?(Hash) }
              raise_node_error!(
                "Code doesn't return items properly",
                description:
                  "Please return an array of #{text_key(:object, plural: true)}, one for each " \
                    "item you would like to output.",
              )
            end

            if value.any? { |item| item.keys.any? { |key| reserved_item_key?(key) } }
              value.each_with_index do |item, index|
                validate_top_level_keys!(item, item_index: index)
              end
            end
          elsif !value.is_a?(Hash)
            raise_node_error!(
              "Code doesn't return items properly",
              description:
                "Please return an array of #{text_key(:object, plural: true)}, one for each item " \
                  "you would like to output.",
            )
          end

          normalize_items!(value).tap do |return_data|
            return_data.each_with_index do |item, index|
              validate_item!(item, item_index: index)
              validate_top_level_keys!(item, item_index: index)
            end
          end
        end

        def normalize_items!(value)
          @execute_functions.helpers.normalize_items(value)
        end

        def validate_item!(item, item_index:)
          unless item["json"].is_a?(Hash)
            raise_node_error!(
              "A 'json' property isn't #{text_key(:object, include_article: true)}",
              description:
                "In the returned data, every key named 'json' must point to " \
                  "#{text_key(:object, include_article: true)}.",
              item_index: item_index,
            )
          end
        end

        def validate_top_level_keys!(item, item_index:)
          found_reserved_key = nil
          unknown_keys = []

          item.each_key do |key|
            if reserved_item_key?(key)
              found_reserved_key ||= key
            else
              unknown_keys << key
            end
          end

          return if unknown_keys.empty?

          if found_reserved_key
            raise_node_error!(
              "Invalid output format",
              description:
                "An output item contains the reserved key #{found_reserved_key}. Wrap each item " \
                  "in an object under a key called json.",
              item_index: item_index,
            )
          end

          raise_node_error!(
            "Unknown top-level item key: #{unknown_keys.first}",
            description: "Access the properties of an item under .json, e.g. item.json",
            item_index: item_index,
          )
        end

        def text_key(key, include_article: false, plural: false)
          response = JS_TEXT_KEYS.fetch(key).fetch(plural ? :plural : :singular)
          return response unless include_article

          article = response.match?(/\A[aeiou]/) ? "an" : "a"
          "#{article} #{response}"
        end

        def reserved_item_key?(key)
          RESERVED_ITEM_KEYS.include?(key.to_s)
        end
      end
    end
  end
end
