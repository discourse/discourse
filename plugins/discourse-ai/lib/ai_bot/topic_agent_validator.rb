# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class TopicAgentValidator
      def self.validate(topic, topic_creator)
        new(topic, topic_creator).validate
      end

      def initialize(topic, topic_creator)
        @topic = topic
        @user = topic_creator.user
        @opts = topic_creator.opts
      end

      def validate
        fields = @opts.dig(:topic_opts, :custom_fields) || @opts[:custom_fields] || {}
        agent = validate_agent_field(fields) || existing_topic_agent
        validate_model_field(fields, agent)
        validate_agent_recipients(agent) if @topic.private_message?
      end

      private

      def validate_agent_field(fields)
        raw_agent_id = fields[TOPIC_AI_AGENT_ID_FIELD] || fields[TOPIC_AI_AGENT_ID_FIELD.to_sym]
        return if raw_agent_id.blank?

        agent_id = parse_id(raw_agent_id, invalid_key: "invalid_agent_id")
        return if agent_id.nil?

        agent = accessible_agent(agent_id)
        allowed =
          @topic.private_message? ? agent&.allow_personal_messages : agent&.allow_topic_mentions
        if !allowed
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
          return
        end

        agent
      end

      def configured_model?(model_id, agent)
        configured_id = agent&.default_llm_id.presence || SiteSetting.ai_default_llm_model.presence
        configured_id.to_i == model_id
      end

      def existing_topic_agent
        agent_id = @topic.custom_fields[TOPIC_AI_AGENT_ID_FIELD].presence&.to_i
        accessible_agent(agent_id) if agent_id
      end

      def validate_model_field(fields, agent)
        raw_model_id =
          fields[TOPIC_AI_LLM_MODEL_ID_FIELD] || fields[TOPIC_AI_LLM_MODEL_ID_FIELD.to_sym]
        return if raw_model_id.blank?

        model_id = parse_id(raw_model_id, invalid_key: "invalid_model_id")
        return if model_id.nil?

        if !LlmModel.exists?(id: model_id) ||
             (
               !LlmModel.enabled_chat_bot_ids.include?(model_id) &&
                 !configured_model?(model_id, agent)
             )
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.model_not_selectable"))
          return
        end

        if agent&.force_default_llm && agent.default_llm_id != model_id
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.model_conflicts_with_agent"))
        end
      end

      def validate_agent_recipients(selected_agent)
        recipient_ids = targeted_user_ids
        if LlmModel.exists?(user_id: recipient_ids)
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.cannot_send_pm_to_model"))
          return
        end

        if selected_agent && !recipient_ids.include?(selected_agent.user_id)
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.agent_recipient_mismatch"))
          return
        end

        targeted = AiAgent.where(user_id: recipient_ids).to_a
        invalid_target =
          targeted.any? do |targeted_agent|
            agent = accessible_agent(targeted_agent.id)
            agent.blank? || !agent.allow_personal_messages
          end
        if invalid_target
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.cannot_send_pm_to_agent"))
        end
      end

      def targeted_user_ids
        usernames = @opts[:target_usernames]
        user_ids = @opts[:target_user_ids]

        if usernames.present?
          usernames = usernames.split(",") if usernames.is_a?(String)
          User.where(
            username_lower: usernames.map { |username| username.to_s.strip.downcase },
          ).pluck(:id)
        else
          Array(user_ids).map(&:to_i)
        end
      end

      def accessible_agent(id)
        DiscourseAi::Agents::Agent.find_by(user: @user, id: id)
      end

      def parse_id(value, invalid_key:)
        raw = value.to_s
        if raw.bytesize > TOPIC_AI_FIELD_ID_MAX_LENGTH
          @topic.errors.add(
            :base,
            I18n.t(
              "custom_fields.validations.max_value_length",
              max_value_length: TOPIC_AI_FIELD_ID_MAX_LENGTH,
            ),
          )
          return
        end

        if !raw.match?(/\A-?\d+\z/) || raw.to_i.zero?
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.#{invalid_key}"))
          return
        end

        raw.to_i
      end
    end
  end
end
