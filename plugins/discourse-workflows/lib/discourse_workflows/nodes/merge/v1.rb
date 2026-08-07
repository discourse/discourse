# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Merge
      class V1 < NodeType
        description(
          name: "flow:merge",
          version: "1.0",
          defaults: {
            icon: "arrows-turn-to-dots",
            color: "blue",
          },
          capabilities: {
            run_scope: "all_items",
          },
          output_contracts: [
            {
              mode: :passthrough,
              variants: [
                {
                  display_options: {
                    show: {
                      mode: ["combine"],
                    },
                    hide: {
                      resolve_clash: %w[prefer_first prefer_last],
                    },
                  },
                },
              ],
            },
          ],
          inputs: [
            { key: "main", type: "main", display_name: "Input", required: false, multiple: true },
          ],
          required_inputs: 1,
          properties: {
            mode: {
              type: :options,
              required: true,
              options: %w[append combine],
              default: "append",
            },
            resolve_clash: {
              type: :options,
              required: false,
              options: %w[add_suffix prefer_first prefer_last],
              default: "add_suffix",
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
            include_unpaired: {
              type: :boolean,
              required: false,
              default: false,
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
          },
        )

        def execute(exec_ctx)
          return [append_inputs(exec_ctx)] unless combine_mode?(exec_ctx)

          @input_item_indexes = item_indexes_by_input(exec_ctx.inputs)
          [combine_by_position(exec_ctx.inputs, combine_config(exec_ctx))]
        end

        private

        def combine_mode?(exec_ctx)
          exec_ctx.get_node_parameter("mode", 0, default: "append") == "combine"
        end

        def combine_config(exec_ctx)
          {
            "include_unpaired" =>
              exec_ctx.get_node_parameter("include_unpaired", 0, default: false),
            "resolve_clash" =>
              exec_ctx.get_node_parameter("resolve_clash", 0, default: "add_suffix"),
          }
        end

        def append_inputs(exec_ctx)
          exec_ctx.inputs.flatten(1)
        end

        def combine_by_position(inputs, config)
          preferred_index = preferred_input_index(config, inputs.length)
          count =
            if config["include_unpaired"]
              inputs.map(&:length).max || 0
            else
              inputs.map(&:length).min || 0
            end

          count.times.map do |index|
            entries = inputs.map { |input| input[index] || { "json" => {} } }
            merge_entries(entries, config, preferred_index:)
          end
        end

        def merge_entries(entries, config, preferred_index:)
          paired_items = paired_items(entries)
          entries = suffix_entries(entries) if config["resolve_clash"] == "add_suffix"
          ordered_entries = entries.dup
          preferred = ordered_entries.delete_at(preferred_index) || { "json" => {} }
          ordered_entries << preferred

          wrap(merge_hashes(ordered_entries.map { |entry| entry.fetch("json") { {} } })).merge(
            "pairedItem" => paired_items,
          )
        end

        def merge_hashes(hashes)
          hashes.each_with_object({}) { |hash, result| merge_deep!(result, hash) }
        end

        def merge_deep!(target, source)
          source.each do |key, value|
            target[key] = if target[key].is_a?(Hash) && value.is_a?(Hash)
              merge_deep!(target[key].dup, value)
            else
              value
            end
          end
          target
        end

        def suffix_entries(entries)
          entries.map.with_index do |entry, index|
            json =
              entry
                .fetch("json") { {} }
                .each_with_object({}) do |(key, value), result|
                  result["#{key}_#{index + 1}"] = value
                end
            entry.merge("json" => json)
          end
        end

        def paired_items(entries)
          entries.each_with_index.filter_map do |entry, input_index|
            paired_item_for_entry(entry, input_index)
          end
        end

        def paired_item_for_entry(entry, input_index)
          item_index = @input_item_indexes&.dig(input_index, entry.object_id)
          return unless item_index

          { "input" => input_index, "item" => item_index }
        end

        def item_indexes_by_input(inputs)
          inputs
            .each_with_index
            .each_with_object({}) do |(items, input_index), indexes|
              indexes[input_index] = items.each_with_index.to_h do |item, item_index|
                [item.object_id, item_index]
              end
            end
        end

        def preferred_input_index(config, input_count)
          config["resolve_clash"] == "prefer_first" ? 0 : input_count - 1
        end
      end
    end
  end
end
