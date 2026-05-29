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
          palette_visible: false,
          capabilities: {
            run_scope: "all_items",
          },
          inputs:
            lambda do |configuration = {}|
              mode = configuration.fetch("mode") { "append" }
              if mode == "append"
                count = [configuration.fetch("number_inputs") { 2 }.to_i, 2].max
                count.times.map { |index| input_port(index, required: false) }
              else
                [input_port(0, required: false), input_port(1, required: false)]
              end
            end,
          required_inputs:
            lambda do |configuration = {}|
              configuration.fetch("mode") { "append" } == "choose_branch" ? [0, 1] : 1
            end,
          properties: {
            mode: {
              type: :options,
              required: true,
              options: %w[append combine choose_branch],
              default: "append",
            },
            number_inputs: {
              type: :integer,
              required: false,
              default: 2,
              min: 2,
              display_options: {
                show: {
                  mode: ["append"],
                },
              },
            },
            combine_by: {
              type: :options,
              required: false,
              options: %w[matching_fields position all],
              default: "matching_fields",
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
            fields_to_match: {
              type: :fixed_collection,
              required: false,
              display_options: {
                show: {
                  mode: ["combine"],
                  combine_by: ["matching_fields"],
                },
              },
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    field_1: {
                      type: :string,
                      required: true,
                      no_data_expression: true,
                    },
                    field_2: {
                      type: :string,
                      required: true,
                      no_data_expression: true,
                    },
                  },
                },
              ],
            },
            join_mode: {
              type: :options,
              required: false,
              options: %w[
                keep_matches
                keep_non_matches
                keep_everything
                enrich_input_1
                enrich_input_2
              ],
              default: "keep_matches",
              display_options: {
                show: {
                  mode: ["combine"],
                  combine_by: ["matching_fields"],
                },
              },
            },
            output_data_from: {
              type: :options,
              required: false,
              options: %w[both input_1 input_2],
              default: "both",
              display_options: {
                show: {
                  mode: ["combine"],
                  combine_by: ["matching_fields"],
                },
              },
            },
            multiple_matches: {
              type: :options,
              required: false,
              options: %w[all first],
              default: "all",
              display_options: {
                show: {
                  mode: ["combine"],
                  combine_by: ["matching_fields"],
                },
              },
            },
            use_data_of_input: {
              type: :options,
              required: false,
              options: %w[input_1 input_2],
              default: "input_1",
              display_options: {
                show: {
                  mode: ["choose_branch"],
                },
              },
            },
            choose_output: {
              type: :options,
              required: false,
              options: %w[specified_input empty],
              default: "specified_input",
              display_options: {
                show: {
                  mode: ["choose_branch"],
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
                  combine_by: ["position"],
                },
              },
            },
            resolve_clash: {
              type: :options,
              required: false,
              options: %w[prefer_last prefer_input_1 prefer_input_2 add_suffix],
              default: "prefer_last",
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
            merge_mode: {
              type: :options,
              required: false,
              options: %w[deep_merge shallow_merge],
              default: "deep_merge",
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
            override_empty: {
              type: :boolean,
              required: false,
              default: false,
              display_options: {
                show: {
                  mode: ["combine"],
                },
              },
            },
            fuzzy_compare: {
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
          config = {
            "mode" => exec_ctx.get_node_parameter("mode", 0, default: "append"),
            "number_inputs" => exec_ctx.get_node_parameter("number_inputs", 0, default: 2),
            "combine_by" =>
              exec_ctx.get_node_parameter("combine_by", 0, default: "matching_fields"),
            "join_mode" => exec_ctx.get_node_parameter("join_mode", 0, default: "keep_matches"),
            "output_data_from" =>
              exec_ctx.get_node_parameter("output_data_from", 0, default: "both"),
            "multiple_matches" =>
              exec_ctx.get_node_parameter("multiple_matches", 0, default: "all"),
            "use_data_of_input" =>
              exec_ctx.get_node_parameter("use_data_of_input", 0, default: "input_1"),
            "choose_output" =>
              exec_ctx.get_node_parameter("choose_output", 0, default: "specified_input"),
            "include_unpaired" =>
              exec_ctx.get_node_parameter("include_unpaired", 0, default: false),
            "resolve_clash" =>
              exec_ctx.get_node_parameter("resolve_clash", 0, default: "prefer_last"),
            "merge_mode" => exec_ctx.get_node_parameter("merge_mode", 0, default: "deep_merge"),
            "override_empty" => exec_ctx.get_node_parameter("override_empty", 0, default: false),
            "fuzzy_compare" => exec_ctx.get_node_parameter("fuzzy_compare", 0, default: false),
          }
          fields_to_match = exec_ctx.get_node_parameter("fields_to_match.values", 0, default: [])
          @input_item_indexes = item_indexes_by_input(exec_ctx.inputs)

          items =
            case config.fetch("mode") { "append" }
            when "append"
              append_inputs(exec_ctx)
            when "choose_branch"
              choose_branch(two_inputs(exec_ctx), config)
            when "combine"
              combine(two_inputs(exec_ctx), config, fields_to_match)
            else
              exec_ctx.input_items("main")
            end

          [items]
        end

        private

        def self.input_port(index, required: true)
          input_number = index + 1
          {
            key: "input_#{input_number}",
            type: "main",
            display_name: "Input #{input_number}",
            label_key: "discourse_workflows.merge.input_#{input_number}",
            required: required,
          }
        end

        def append_inputs(exec_ctx)
          indexed_items = exec_ctx.inputs.flatten(1)
          return indexed_items if indexed_items.present?

          exec_ctx.input_items("main")
        end

        def two_inputs(exec_ctx)
          [exec_ctx.input_items(0), exec_ctx.input_items(1)]
        end

        def choose_branch(inputs, config)
          return [wrap({})] if config.fetch("choose_output") { "specified_input" } == "empty"

          selected_input_index(config) == 0 ? inputs[0] : inputs[1]
        end

        def combine(inputs, config, fields_to_match)
          case config.fetch("combine_by") { "matching_fields" }
          when "position"
            combine_by_position(inputs, config)
          when "all"
            combine_all(inputs, config)
          else
            combine_by_fields(inputs, config, fields_to_match)
          end
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

        def combine_all(inputs, config)
          input_1, input_2 = inputs
          return [] if input_1.blank? || input_2.blank?

          preferred_index = preferred_input_index(config, inputs.length)
          input_1.flat_map do |entry_1|
            input_2.map { |entry_2| merge_entries([entry_1, entry_2], config, preferred_index:) }
          end
        end

        def combine_by_fields(inputs, config, fields_to_match)
          input_1, input_2 = inputs
          join_mode = config.fetch("join_mode") { "keep_matches" }
          output_data_from = config.fetch("output_data_from") { "both" }
          fields = match_fields(fields_to_match)
          validate_match_fields!(fields)
          if input_1.blank? || input_2.blank?
            return combine_by_fields_with_empty_input(input_1, input_2, join_mode, output_data_from)
          end

          matches = find_matches(input_1, input_2, fields, config)

          case join_mode
          when "keep_non_matches"
            non_matches(matches, output_data_from)
          when "keep_everything"
            matched_output(matches, output_data_from, config) + matches[:unmatched_1] +
              matches[:unmatched_2]
          when "enrich_input_1"
            merge_matched(matches[:matched], config) + matches[:unmatched_1]
          when "enrich_input_2"
            merge_matched(matches[:matched], config, preferred_index: 1) + matches[:unmatched_2]
          else
            matched_output(matches, output_data_from, config)
          end
        end

        def combine_by_fields_with_empty_input(input_1, input_2, join_mode, output_data_from)
          case join_mode
          when "keep_non_matches"
            case output_data_from
            when "input_1"
              input_1
            when "input_2"
              input_2
            else
              input_1 + input_2
            end
          when "keep_everything"
            input_1 + input_2
          when "enrich_input_1"
            input_1.presence || []
          when "enrich_input_2"
            input_2.presence || []
          else
            []
          end
        end

        def match_fields(fields_to_match)
          fields_to_match.map.with_index do |field, index|
            field_1 = field["field_1"].presence
            field_2 = field["field_2"].presence || field_1
            if field_1.blank? || field_2.blank?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.merge.invalid_fields_to_match"),
                description:
                  I18n.t(
                    "discourse_workflows.errors.merge.fields_to_match_pair_missing_fields",
                    index: index + 1,
                  ),
              )
            end

            [field_1, field_2]
          end
        end

        def validate_match_fields!(fields)
          if fields.blank?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.merge.missing_fields_to_match"),
              description: I18n.t("discourse_workflows.errors.merge.fields_to_match_required"),
            )
          end
        end

        def find_matches(input_1, input_2, fields, config)
          matched_input_2_indexes = Set.new
          result = { matched: [], matched_2: [], unmatched_1: [], unmatched_2: [] }

          input_1.each do |entry_1|
            matches =
              input_2.each_with_index.filter_map do |entry_2, index|
                next unless fields_match?(entry_1, entry_2, fields, config)

                matched_input_2_indexes << index
                entry_2
              end
            matches = matches.first(1) if config.fetch("multiple_matches") { "all" } == "first"

            if matches.any?
              result[:matched] << [entry_1, matches]
            else
              result[:unmatched_1] << entry_1
            end
          end

          input_2.each_with_index do |entry, index|
            if matched_input_2_indexes.include?(index)
              result[:matched_2] << entry
            else
              result[:unmatched_2] << entry
            end
          end

          result
        end

        def fields_match?(entry_1, entry_2, fields, config)
          fields.all? do |field_1, field_2|
            present_1, value_1 = field_lookup(entry_1, field_1)
            present_2, value_2 = field_lookup(entry_2, field_2)
            next false if !present_1 || !present_2

            compare_values(value_1, value_2, fuzzy: config["fuzzy_compare"])
          end
        end

        def compare_values(value_1, value_2, fuzzy:)
          fuzzy ? value_1.to_s == value_2.to_s : value_1 == value_2
        end

        def matched_output(matches, output_data_from, config)
          case output_data_from
          when "input_1"
            matches[:matched].map(&:first)
          when "input_2"
            matches[:matched_2]
          else
            merge_matched(matches[:matched], config)
          end
        end

        def non_matches(matches, output_data_from)
          case output_data_from
          when "input_1"
            matches[:unmatched_1]
          when "input_2"
            matches[:unmatched_2]
          else
            matches[:unmatched_1].map { |item| add_source(item, "input_1") } +
              matches[:unmatched_2].map { |item| add_source(item, "input_2") }
          end
        end

        def merge_matched(matched, config, preferred_index: nil)
          preferred_index ||= preferred_input_index(config, 2)
          matched.flat_map do |entry_1, matches|
            matches.map { |entry_2| merge_entries([entry_1, entry_2], config, preferred_index:) }
          end
        end

        def merge_entries(entries, config, preferred_index:)
          paired_items = paired_items(entries)
          entries = suffix_entries(entries) if config["resolve_clash"] == "add_suffix"
          ordered_entries = entries.dup
          preferred = ordered_entries.delete_at(preferred_index) || { "json" => {} }
          ordered_entries << preferred

          wrap(
            merge_hashes(ordered_entries.map { |entry| entry.fetch("json") { {} } }, config),
          ).merge("pairedItem" => paired_items)
        end

        def merge_hashes(hashes, config)
          hashes.each_with_object({}) do |hash, result|
            if config.fetch("merge_mode") { "deep_merge" } == "shallow_merge"
              merge_shallow!(result, hash, config)
            else
              merge_deep!(result, hash, config)
            end
          end
        end

        def merge_shallow!(target, source, config)
          source.each { |key, value| target[key] = merged_value(target[key], value, config) }
          target
        end

        def merge_deep!(target, source, config)
          source.each do |key, value|
            target[key] = if target[key].is_a?(Hash) && value.is_a?(Hash)
              merge_deep!(target[key].dup, value, config)
            else
              merged_value(target[key], value, config)
            end
          end
          target
        end

        def merged_value(existing, incoming, config)
          return existing if config["override_empty"] && blank_merge_value?(incoming)

          incoming
        end

        def blank_merge_value?(value)
          value.nil? || value == ""
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

        def add_source(item, source)
          wrap(item.fetch("json") { {} }.merge("_source" => source)).merge(
            "pairedItem" => paired_item_for_entry(item, input_index(source)),
          ).compact
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
          case config["resolve_clash"]
          when "prefer_input_1"
            0
          when "prefer_input_2"
            1
          else
            input_count - 1
          end
        end

        def input_index(input_name)
          input_name.to_s == "input_2" ? 1 : 0
        end

        def selected_input_index(config)
          config["use_data_of_input_index"] ||
            input_index(config.fetch("use_data_of_input") { "input_1" })
        end

        def field_lookup(item, field)
          value = item.fetch("json") { {} }
          field
            .to_s
            .split(".")
            .each do |key|
              return false, nil unless value.is_a?(Hash) && value.key?(key)

              value = value[key]
            end

          [true, value]
        end
      end
    end
  end
end
