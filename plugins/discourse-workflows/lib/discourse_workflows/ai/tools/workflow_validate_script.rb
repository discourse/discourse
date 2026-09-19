# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowValidateScript < Base
        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"
        MODES = [RUN_ONCE_FOR_ALL_ITEMS, RUN_ONCE_FOR_EACH_ITEM].freeze
        DISALLOWED_FOR_EACH_METHODS = %w[first last all itemMatching].freeze
        RESERVED_ITEM_KEYS = %w[json pairedItem error index].freeze
        MAX_SAMPLE_ITEMS = 20
        MAX_CODE_BYTES = 20_000

        def self.signature
          {
            name: name,
            description:
              "Validates JavaScript generated for a Discourse workflow Code node against syntax, mode restrictions, and return shape.",
            parameters: [
              { name: "mode", description: "Code node mode", type: "string", required: true },
              { name: "code", description: "JavaScript source", type: "string", required: true },
              {
                name: "sample_input_items",
                description: "Optional sample input items to execute the script against",
                type: "array",
                required: false,
              },
            ],
          }
        end

        def self.name
          "workflow_validate_script"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          mode = parameters[:mode].to_s
          code = parameters[:code].to_s
          sample_input_items = Array.wrap(parameters[:sample_input_items]).first(MAX_SAMPLE_ITEMS)
          errors = []
          warnings = []

          errors << "Mode must be one of #{MODES.join(", ")}" if MODES.exclude?(mode)
          errors << "Code is required" if code.blank?
          errors << "Code exceeds #{MAX_CODE_BYTES} bytes" if code.bytesize > MAX_CODE_BYTES
          errors.concat(disallowed_method_errors(code)) if mode == RUN_ONCE_FOR_EACH_ITEM

          return invalid_response(errors, warnings) if errors.present?

          sample_output_items = execute_sample(code, mode, sample_input_items)
          validate_output_shape(sample_output_items, mode, errors, warnings)

          {
            status: "success",
            valid: errors.empty?,
            errors: errors,
            warnings: warnings,
            sample_output_items: errors.empty? ? sample_output_items : [],
          }
        rescue MiniRacer::Error => e
          invalid_response(["JavaScript execution error: #{e.message}"], [])
        end

        private

        def invalid_response(errors, warnings)
          {
            status: "success",
            valid: false,
            errors: errors,
            warnings: warnings,
            sample_output_items: [],
          }
        end

        def disallowed_method_errors(code)
          code
            .scan(/\$input\.(#{DISALLOWED_FOR_EACH_METHODS.join("|")})\b/)
            .flatten
            .uniq
            .map { |method| "$input.#{method} is only available in #{RUN_ONCE_FOR_ALL_ITEMS} mode" }
        end

        def execute_sample(code, mode, sample_input_items)
          context = MiniRacer::Context.new(timeout: 100, max_memory: 10.megabytes)
          context.eval("var __sampleInputItems = #{sample_items_json(sample_input_items)};")
          context.eval(runtime_js(mode))
          context.eval("(function() {\n#{code}\n}).call({});")
        ensure
          context&.dispose
        end

        def sample_items_json(sample_input_items)
          items = sample_input_items.presence || [{ "json" => {} }]
          JSON.generate(items)
        end

        def runtime_js(mode)
          <<~JS
            var __mode = #{mode.to_json};
            var __currentItem = __sampleInputItems[0] || { json: {} };
            var $input = Object.freeze({
              item: __currentItem,
              all: function() { return __sampleInputItems; },
              first: function() { return __sampleInputItems[0] || { json: {} }; },
              last: function() { return __sampleInputItems[__sampleInputItems.length - 1] || { json: {} }; },
              itemMatching: function(index) { return __sampleInputItems[index] || { json: {} }; }
            });
            var $json = __currentItem.json || {};
            var $vars = Object.freeze({});
            var $site_settings = Object.freeze({});
            var $execution = Object.freeze({});
            var $current_user = Object.freeze({});
            var console = Object.freeze({
              log: function() {},
              info: function() {},
              warn: function() {},
              error: function() {}
            });
            function $(name) {
              return Object.freeze({
                item: { json: {} },
                all: function() { return []; },
                first: function() { return { json: {} }; },
                last: function() { return { json: {} }; }
              });
            }
          JS
        end

        def validate_output_shape(output, mode, errors, warnings)
          if mode == RUN_ONCE_FOR_EACH_ITEM
            validate_each_item_output(output, errors, warnings)
          else
            validate_all_items_output(output, errors, warnings)
          end
        end

        def validate_each_item_output(output, errors, warnings)
          if output.is_a?(Array)
            errors << "#{RUN_ONCE_FOR_EACH_ITEM} must return one object, not an array"
            return
          end

          validate_item(output, errors, warnings)
        end

        def validate_all_items_output(output, errors, warnings)
          if output.nil?
            warnings << "Script returned null or undefined; this produces no output items"
            return
          end

          unless output.is_a?(Array) || output.is_a?(Hash)
            errors << "#{RUN_ONCE_FOR_ALL_ITEMS} must return an array of objects or one object"
            return
          end

          Array.wrap(output).each { |item| validate_item(item, errors, warnings) }
        end

        def validate_item(item, errors, warnings)
          unless item.is_a?(Hash)
            errors << "Output item must be an object"
            return
          end

          validate_top_level_keys(item, errors, warnings)
          if item.key?("json") && !item["json"].is_a?(Hash)
            errors << "Output item json field must be an object"
          end
        end

        def validate_top_level_keys(item, errors, warnings)
          unknown_keys = item.keys.reject { |key| reserved_item_key?(key) }
          return if unknown_keys.empty?

          if item.keys.any? { |key| reserved_item_key?(key) }
            errors << "Output item mixes reserved item keys with plain fields"
          else
            warnings << "Output item is a plain object and will be normalized under json"
          end
        end

        def reserved_item_key?(key)
          RESERVED_ITEM_KEYS.include?(key.to_s)
        end
      end
    end
  end
end
