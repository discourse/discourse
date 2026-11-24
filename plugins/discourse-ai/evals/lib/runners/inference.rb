# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Inference < Base
        Candidate = Struct.new(:id, :name, :description, :aliases)

        OPERATIONS = {
          "generate_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptFinder,
            schema_key: :matches,
            schema_type: "array",
          },
          "match_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptMatcher,
            schema_key: :matches,
            schema_type: "array",
          },
          "deduplicate_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptDeduplicator,
            schema_key: :merges,
            schema_type: "array",
          },
        }.freeze

        def self.can_handle?(feature_name)
          feature_name&.start_with?("inference:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args || {}

          response =
            case feature_name
            when "generate_concepts"
              generate_concepts(args, llm, execution_context:)
            when "match_concepts"
              match_concepts(args, llm, execution_context:)
            when "deduplicate_concepts"
              deduplicate_concepts(args, llm, execution_context:)
            else
              raise ArgumentError, "Unsupported inference feature '#{feature_name}'"
            end

          response
        end

        private

        def generate_concepts(args, llm, execution_context:)
          content = conversation_to_text(args)
          raise ArgumentError, "Missing input for generate concepts eval" if content.blank?

          candidates = build_candidates(args[:existing_concepts])
          agent, user = agent_bundle(feature_name)
          payload = {
            content: content,
            candidates:
              DiscourseAi::InferredConcepts::CandidateRetriever.serialize_candidates(candidates),
          }

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: payload.to_json }] }

          structured_output =
            capture_structured_object(agent, user, llm, context, execution_context:)
          values = extract_concept_names(structured_output, candidates, include_proposed: true)
          wrap_result(format_response(values), { query: content })
        end

        def match_concepts(args, llm, execution_context:)
          content = conversation_to_text(args)
          raw_concepts = args[:concepts].to_a.map(&:to_s)
          if content.blank? || raw_concepts.empty?
            raise ArgumentError, "Match concepts eval requires :input/:conversation and :concepts"
          end

          candidates = build_candidates(raw_concepts)
          agent, user = agent_bundle(feature_name)
          payload = {
            content: content,
            candidates:
              DiscourseAi::InferredConcepts::CandidateRetriever.serialize_candidates(candidates),
          }

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: payload.to_json }] }

          structured_output =
            capture_structured_object(agent, user, llm, context, execution_context:)
          values = extract_concept_names(structured_output, candidates, include_proposed: false)
          wrap_result(format_response(values), { query: content, concepts: raw_concepts })
        end

        def deduplicate_concepts(args, llm, execution_context:)
          names = args[:concepts].to_a.map(&:to_s)
          raise ArgumentError, "Deduplicate concepts eval requires :concepts" if names.empty?

          agent, user = agent_bundle(feature_name)
          candidates = build_candidates(names)
          payload = {
            concepts:
              candidates.map do |concept|
                {
                  id: concept.id,
                  name: concept.name,
                  description: concept.description,
                  aliases: concept.aliases,
                  status: "active",
                  parent_id: nil,
                  usage_count: 1,
                }
              end,
          }

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: payload.to_json }] }

          structured_output =
            capture_structured_object(agent, user, llm, context, execution_context:)
          values = extract_surviving_concept_names(structured_output, candidates)
          wrap_result(format_response(values), { concepts: names })
        end

        def agent_bundle(op)
          config = OPERATIONS.fetch(op) { raise ArgumentError }
          agent_klass = config.fetch(:agent_class)

          resolve_agent(agent_class: agent_klass)
        end

        def capture_structured_object(agent, user, llm, context, execution_context:)
          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          structured_output = nil
          bot.reply(context, execution_context:) do |partial, _, type|
            structured_output = partial if type == :structured_output
          end
          structured_output
        end

        def build_candidates(names)
          Array(names).each_with_index.map do |name, index|
            Candidate.new(index + 1, name.to_s, "", [])
          end
        end

        def extract_concept_names(structured_output, candidates, include_proposed:)
          return [] if structured_output.nil?

          by_id = candidates.index_by(&:id)
          matches =
            Array(structured_output.read_buffered_property(:matches)).filter_map do |item|
              next unless item.is_a?(Hash)
              by_id[item.with_indifferent_access[:concept_id]&.to_i]&.name
            end

          return matches unless include_proposed

          proposed =
            Array(structured_output.read_buffered_property(:proposed_new)).filter_map do |item|
              next unless item.is_a?(Hash)
              item.with_indifferent_access[:name].presence
            end

          (matches + proposed).uniq
        end

        def extract_surviving_concept_names(structured_output, candidates)
          names = candidates.map(&:name)
          return names if structured_output.nil?

          valid_ids = candidates.map(&:id).to_set
          absorbed_ids = Set.new

          Array(structured_output.read_buffered_property(:merges)).each do |item|
            next unless item.is_a?(Hash)

            entry = item.with_indifferent_access
            canonical_id = entry[:canonical_id]&.to_i
            next if canonical_id.nil? || !valid_ids.include?(canonical_id)

            Array(entry[:merge_ids]).each do |merge_id|
              id = merge_id&.to_i
              next if id.nil? || id == canonical_id || !valid_ids.include?(id)

              absorbed_ids << id
            end
          end

          candidates.reject { |candidate| absorbed_ids.include?(candidate.id) }.map(&:name)
        end

        def conversation_to_text(args)
          if args[:conversation].present?
            Array(args[:conversation]).join("\n\n")
          else
            args[:input].to_s
          end
        end

        def format_response(values)
          if values.is_a?(Array)
            values.map { |item| item.to_s.strip }.reject(&:blank?).join("\n")
          else
            values.to_s
          end
        end

        def build_ctx
          DiscourseAi::Agents::BotContext.new(
            user: Discourse.system_user,
            skip_show_thinking: true,
            feature_name: "evals/inference/#{feature_name}",
          )
        end
      end
    end
  end
end
