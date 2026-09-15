# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationRoute
      class Error < StandardError
        attr_reader :param

        def initialize(message, param: nil)
          @param = param
          super(message)
        end
      end

      Result =
        Data.define(
          :agent_record,
          :agent_class,
          :speaker,
          :model,
          :model_source,
          :authorization_user,
          :modality,
        ) do
          def agent_id
            agent_record.id
          end

          def llm_model_id
            model.id
          end
        end

      class << self
        def resolve(
          authorization_user:,
          modality:,
          agent_id: nil,
          llm_model_id: nil,
          topic: nil,
          recipient_user: nil,
          selection_source: :request,
          allow_general_fallback: true
        )
          new(
            authorization_user:,
            modality:,
            agent_id:,
            llm_model_id:,
            topic:,
            recipient_user:,
            selection_source:,
            allow_general_fallback:,
          ).resolve
        end
      end

      def initialize(
        authorization_user:,
        modality:,
        agent_id:,
        llm_model_id:,
        topic:,
        recipient_user:,
        selection_source:,
        allow_general_fallback:
      )
        @authorization_user = authorization_user
        @modality = modality.to_sym
        @agent_id = agent_id
        @llm_model_id = llm_model_id
        @topic = topic
        @recipient_user = recipient_user
        @selection_source = selection_source.to_sym
        @allow_general_fallback = allow_general_fallback
      end

      def resolve
        validate_global_access!
        agent_class = resolve_agent_class
        validate_modality!(agent_class)
        agent_record = AiAgent.find_by(id: agent_class.id)
        speaker = agent_record&.user
        raise_error(:ai_agent_id, "no_user_for_agent") if speaker.blank? || !speaker.active?

        validate_recipient!(agent_record)
        model, model_source = resolve_model(agent_record, agent_class)

        Result.new(
          agent_record:,
          agent_class:,
          speaker:,
          model:,
          model_source:,
          authorization_user: @authorization_user,
          modality: @modality,
        )
      end

      private

      def validate_global_access!
        discussion_modality = %i[
          personal_message
          topic_mention
          chat_direct_message
          chat_channel_mention
        ].include?(@modality)
        if discussion_modality && !SiteSetting.ai_bot_enabled
          raise_error(:ai_agent_id, "bot_disabled")
        end
        return if @modality != :personal_message
        return if @authorization_user&.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)

        raise_error(:ai_agent_id, "bot_not_allowed")
      end

      def resolve_agent_class
        id = normalized_id(@agent_id, :ai_agent_id) if @agent_id.present?
        id ||= topic_agent_id
        id ||= recipient_agent_id

        if id
          if @modality == :automation
            record = AiAgent.find_by(id:, enabled: true)
            raise_error(:ai_agent_id, "invalid_agent_id") if record.blank?
            return record.class_instance
          end

          agent = DiscourseAi::Agents::Agent.find_by(user: @authorization_user, id: id)
          raise_error(:ai_agent_id, "invalid_agent_id") if agent.blank?
          return agent
        end

        if (legacy_name = @topic&.custom_fields&.[]("ai_agent").presence)
          agent = DiscourseAi::Agents::Agent.find_by(user: @authorization_user, name: legacy_name)
          return agent if agent
        end

        if @allow_general_fallback
          general_id = DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General]
          agent = DiscourseAi::Agents::Agent.find_by(user: @authorization_user, id: general_id)
          return agent if agent
        end

        raise_error(:ai_agent_id, "agent_required")
      end

      def topic_agent_id
        raw_id = @topic&.custom_fields&.[](TOPIC_AI_AGENT_ID_FIELD).presence
        normalized_id(raw_id, :ai_agent_id) if raw_id
      end

      def recipient_agent_id
        return if @recipient_user.blank?

        ids =
          AiAgent
            .where(enabled: true, user_id: @recipient_user.id)
            .where.not(user_id: nil)
            .pluck(:id)
        return ids.first if ids.one?
        raise_error(:target_username, "ambiguous_agent") if ids.many?
      end

      def validate_modality!(agent)
        allowed =
          case @modality
          when :personal_message
            agent.allow_personal_messages
          when :topic_mention
            agent.allow_topic_mentions
          when :chat_direct_message
            agent.allow_chat_direct_messages
          when :chat_channel_mention
            agent.allow_chat_channel_mentions
          when :automation, :streaming
            true
          else
            false
          end

        raise_error(:ai_agent_id, "invalid_agent_modality") if !allowed
      end

      def validate_recipient!(agent_record)
        return if @recipient_user.blank?
        return if @recipient_user.id == agent_record.user_id
        return if LlmModel.exists?(user_id: @recipient_user.id)

        raise_error(:target_username, "agent_recipient_mismatch")
      end

      def resolve_model(agent_record, agent_class)
        requested_id = normalized_id(@llm_model_id, :ai_llm_model_id) if @llm_model_id.present?
        persisted_topic_id = topic_model_id
        topic_id = persisted_topic_id if requested_id.blank?
        legacy_id = legacy_model_id if requested_id.blank? && topic_id.blank?

        if agent_class.force_default_llm
          forced_id = agent_record.default_llm_id
          raise_error(:ai_llm_model_id, "no_model_available") if forced_id.blank?
          if requested_id.present? && requested_id != forced_id
            raise_error(:ai_llm_model_id, "model_conflicts_with_agent")
          end
          return find_model!(forced_id), :forced
        end

        selected_id = requested_id || topic_id || legacy_id
        if selected_id
          source = model_selection_source(requested_id, topic_id)
          configured_source = configured_model_source(selected_id, agent_record)
          inherited_configured_model =
            source == :topic || (source == :request && persisted_topic_id == selected_id)
          source = configured_source if configured_source && inherited_configured_model
          if %i[request topic].include?(source) &&
               !LlmModel.enabled_chat_bot_ids.include?(selected_id)
            raise_error(:ai_llm_model_id, "model_not_selectable")
          end
          return find_model!(selected_id), source
        end

        default_id =
          agent_record.default_llm_id.presence || SiteSetting.ai_default_llm_model.presence
        raise_error(:ai_llm_model_id, "no_model_available") if default_id.blank?

        source = agent_record.default_llm_id.present? ? :agent_default : :site_default
        [find_model!(default_id), source]
      end

      def configured_model_source(model_id, agent_record)
        return :agent_default if agent_record.default_llm_id == model_id
        if agent_record.default_llm_id.blank? && SiteSetting.ai_default_llm_model.to_i == model_id
          :site_default
        end
      end

      def model_selection_source(requested_id, topic_id)
        return @selection_source if requested_id
        return :topic if topic_id
        if @recipient_user.present? && @topic.blank? && @selection_source == :request
          return :request
        end

        :legacy
      end

      def topic_model_id
        raw_id = @topic&.custom_fields&.[](TOPIC_AI_LLM_MODEL_ID_FIELD).presence
        normalized_id(raw_id, :ai_llm_model_id) if raw_id
      end

      def legacy_model_id
        if @recipient_user && (model_id = LlmModel.where(user_id: @recipient_user.id).pick(:id))
          return model_id
        end

        preferred_user_id =
          @topic
            &.custom_fields
            &.[](DiscourseAi::AiBot::Playground::BOT_USER_PREF_ID_CUSTOM_FIELD)
            .to_i
        if preferred_user_id != 0 &&
             (model_id = LlmModel.where(user_id: preferred_user_id).pick(:id))
          return model_id
        end

        provenance_model_id = latest_response_model_id
        return provenance_model_id if provenance_model_id

        legacy_participant_model_ids
      end

      def latest_response_model_id
        return if @topic.blank?

        value =
          PostCustomField
            .joins(:post)
            .where(posts: { topic_id: @topic.id }, name: POST_AI_LLM_MODEL_ID_FIELD)
            .order("posts.post_number DESC")
            .pick(:value)
        model_id = value.to_i
        model_id if !model_id.zero?
      end

      def legacy_participant_model_ids
        return if @topic.blank?

        participant_ids = @topic.topic_allowed_users.pluck(:user_id)
        model_ids = LlmModel.where(user_id: participant_ids).pluck(:id).uniq
        return model_ids.first if model_ids.one?
        raise_error(:ai_llm_model_id, "ambiguous_model") if model_ids.many?
      end

      def find_model!(id)
        LlmModel.find_by(id:) || raise_error(:ai_llm_model_id, "model_unavailable")
      end

      def normalized_id(value, param)
        raw = value.to_s
        if raw.bytesize > TOPIC_AI_FIELD_ID_MAX_LENGTH || !raw.match?(/\A-?\d+\z/) || raw.to_i.zero?
          raise_error(param, param == :ai_agent_id ? "invalid_agent_id" : "invalid_model_id")
        end
        raw.to_i
      end

      def raise_error(param, key)
        raise Error.new(I18n.t("discourse_ai.ai_bot.errors.#{key}"), param:)
      end
    end
  end
end
