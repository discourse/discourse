# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class ContinueConversation
      MAX_QUESTION_LENGTH = 1000
      TOPIC_REQUEST_ID_FIELD = "ai_discovery_request_id"

      class ResultExpired < StandardError
      end

      def initialize(user:, discovery_agent:, follow_up_agent:)
        @user = user
        @discovery_agent = discovery_agent
        @follow_up_agent = follow_up_agent
        @guardian = Guardian.new(user)
      end

      def call(request_id:, question:)
        if !DiscourseAi::Discoveries.valid_request_id?(request_id)
          raise Discourse::InvalidParameters.new(
                  I18n.t("discourse_ai.ai_bot.discoveries.errors.invalid_request_id"),
                )
        end

        result = DiscourseAi::Discoveries.cached_result_for(user: @user, request_id:)
        raise ResultExpired if result.nil? || result["agent_id"] != @discovery_agent.id
        if !SiteSetting.ai_bot_enabled ||
             !@user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          raise Discourse::InvalidAccess
        end
        if @follow_up_agent.nil? || !@follow_up_agent.enabled? ||
             !@user.in_any_groups?(@follow_up_agent.allowed_group_ids) ||
             !@follow_up_agent.allow_personal_messages
          raise Discourse::InvalidAccess
        end

        route =
          DiscourseAi::AiBot::ConversationRoute.resolve(
            authorization_user: @user,
            modality: :personal_message,
            agent_id: @follow_up_agent.id,
            selection_source: :snapshot,
            allow_general_fallback: false,
          )
        @guardian.ensure_can_send_pm_to_ai_bot!(route.speaker)
        question = normalized_question(question)

        DistributedMutex.synchronize(lock_key(request_id), validity: 30) do
          if (topic = existing_topic(request_id))
            return topic.id
          end

          RateLimiter.new(@user, "ai_discover_#{@user.id}_continue_convo", 3, 1.minute).performed!

          topic_id = create_conversation(result, route, question, request_id).id
          Discourse.redis.set(
            topic_key(request_id),
            topic_id,
            ex: DiscourseAi::Discoveries::REQUEST_TTL,
          )
          topic_id
        end
      end

      private

      def normalized_question(question)
        question = question.to_s.strip
        return if question.blank?

        if question.length > MAX_QUESTION_LENGTH || question.include?("\0")
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "discourse_ai.ai_bot.discoveries.errors.invalid_follow_up",
                    max: MAX_QUESTION_LENGTH,
                  ),
                )
        end

        question
      end

      def existing_topic(request_id)
        topic_id = Discourse.redis.get(topic_key(request_id))
        topic_id ||=
          TopicCustomField.where(
            name: TOPIC_REQUEST_ID_FIELD,
            value: request_token(request_id),
          ).pick(:topic_id)
        return if topic_id.blank?

        topic = Topic.find_by(id: topic_id, deleted_at: nil)
        return topic if topic && @guardian.can_see_topic?(topic)

        Discourse.redis.del(topic_key(request_id))
        nil
      end

      def create_conversation(result, route, question, request_id)
        query = result.fetch("query")
        topic = nil
        question_post = nil

        Post.transaction do
          title =
            I18n.t(
              "discourse_ai.ai_bot.discoveries.continue_conversation.title",
              query: query,
            ).truncate(SiteSetting.max_topic_title_length)
          query_post =
            PostCreator.create!(
              @user,
              title:,
              raw: neutralize_mentions(query),
              archetype: Archetype.private_message,
              private_message_context: DiscourseAi::AiBot::PERSONAL_MESSAGE_CONTEXT,
              target_usernames: route.speaker.username,
              topic_opts: {
                custom_fields: {
                  DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => route.agent_id,
                  DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD => route.llm_model_id,
                  TOPIC_REQUEST_ID_FIELD => request_token(request_id),
                },
              },
              custom_fields: {
                DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
              },
              skip_validations: true,
            )
          topic = query_post.topic

          PostCreator.create!(
            route.speaker,
            topic_id: topic.id,
            raw: model_turn(result),
            custom_fields: {
              DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => @discovery_agent.id,
            },
            skip_validations: true,
          )

          if question.present?
            question_post =
              PostCreator.create!(
                @user,
                topic_id: topic.id,
                raw: neutralize_mentions(question),
                custom_fields: {
                  DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
                },
                skip_validations: true,
              )
          end
        end

        if question_post
          bot =
            DiscourseAi::Agents::Bot.as(
              route.speaker,
              agent: route.agent_class.new,
              model: route.model,
            )
          question_post.custom_fields.delete(
            DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD,
          )
          question_post.save_custom_fields
          DiscourseAi::AiBot::Playground.new(bot).update_playground_with(
            question_post,
            authorization_user: @user,
          )
        end

        topic
      end

      def model_turn(result)
        context = []
        context << neutralize_mentions(result.fetch("answer")) if result["answer"].present?

        sources =
          result
            .fetch("sources")
            .map do |source|
              I18n.t(
                "discourse_ai.ai_bot.discoveries.continue_conversation.source",
                title:
                  source
                    .fetch("title")
                    .gsub(/[\\\[\]]/) { |character| "\\#{character}" }
                    .gsub("@", "&#64;"),
                url: source.fetch("url"),
              )
            end
        context << I18n.t(
          "discourse_ai.ai_bot.discoveries.continue_conversation.sources",
          sources: sources.join("\n"),
        )
        context.join("\n\n")
      end

      def neutralize_mentions(text)
        text.to_s.gsub("@", "&#64;")
      end

      def lock_key(request_id)
        "discourse-ai:discoveries:follow-up-lock:#{@user.id}:#{request_id.downcase}"
      end

      def topic_key(request_id)
        "discourse-ai:discoveries:follow-up-topic:#{@user.id}:#{request_id.downcase}"
      end

      def request_token(request_id)
        "#{@user.id}:#{request_id.downcase}"
      end
    end
  end
end
