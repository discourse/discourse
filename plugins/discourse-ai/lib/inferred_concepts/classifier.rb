# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Classifier
      MIN_RELEVANCE = 0.5
      MAX_NAME_LENGTH = 80
      MAX_DESCRIPTION_LENGTH = 1000

      def self.resolve_agent(allow_new: true)
        agent_id =
          if allow_new
            SiteSetting.inferred_concepts_generate_agent.to_i
          else
            SiteSetting.inferred_concepts_match_agent.to_i
          end

        AiAgent.all_agents(enabled_only: false).find { |agent| agent.id == agent_id }&.new
      end

      def self.resolve_llm(allow_new: true, agent: resolve_agent(allow_new:))
        return nil if agent.nil?

        LlmModel.find_by(
          id: agent.class.default_llm_id.presence || SiteSetting.ai_default_llm_model,
        )
      end

      def classify(content, candidates: [], allow_new: true)
        empty = { matches: [], proposed_new: [] }
        return empty if content.blank? || (!allow_new && candidates.blank?)

        agent = self.class.resolve_agent(allow_new:)
        return empty if agent.nil?

        llm = self.class.resolve_llm(allow_new:, agent:)
        return empty if llm.nil?

        payload = {
          content: content,
          candidates: CandidateRetriever.serialize_candidates(candidates),
        }

        context =
          DiscourseAi::Agents::BotContext.new(
            messages: [{ type: :user, content: payload.to_json }],
            user: Discourse.system_user,
            feature_name: allow_new ? "inferred_concepts_generate" : "inferred_concepts_match",
          )

        bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent, model: llm)
        structured_output = nil

        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        return empty if structured_output.nil?

        valid_ids = candidates.map(&:id).to_set
        {
          matches: sanitize_matches(structured_output.read_buffered_property(:matches), valid_ids),
          proposed_new:
            if allow_new
              sanitize_proposed(structured_output.read_buffered_property(:proposed_new), valid_ids)
            else
              []
            end,
        }
      end

      private

      def sanitize_matches(raw_matches, valid_ids)
        by_id = {}

        Array(raw_matches).each do |item|
          next unless item.is_a?(Hash)

          entry = item.with_indifferent_access
          concept_id = entry[:concept_id]&.to_i
          next if concept_id.nil? || !valid_ids.include?(concept_id)

          relevance = entry[:relevance].to_f.clamp(0.0, 1.0)
          next if relevance < MIN_RELEVANCE

          primary = entry[:primary] == true
          existing = by_id[concept_id]
          if existing.nil? || relevance > existing[:relevance]
            by_id[concept_id] = { concept_id:, relevance:, primary: }
          elsif primary && !existing[:primary]
            existing[:primary] = true
          end
        end

        by_id.values
      end

      def sanitize_proposed(raw_proposed, valid_ids)
        by_name = {}

        Array(raw_proposed).each do |item|
          next unless item.is_a?(Hash)

          entry = item.with_indifferent_access
          name = normalize_utf8(entry[:name]).strip.first(MAX_NAME_LENGTH)
          next if name.blank?

          key = name.downcase
          next if by_name.key?(key)

          description = normalize_utf8(entry[:description]).strip.first(MAX_DESCRIPTION_LENGTH)
          raw_parent_id = entry[:parent_concept_id]&.to_i
          parent_concept_id =
            (
              if raw_parent_id && raw_parent_id > 0 && valid_ids.include?(raw_parent_id)
                raw_parent_id
              else
                nil
              end
            )

          by_name[key] = { name:, description:, parent_concept_id: }
        end

        by_name.values
      end

      def normalize_utf8(value)
        str = value.to_s
        return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

        str.dup.force_encoding(Encoding::UTF_8).scrub("")
      end
    end
  end
end
