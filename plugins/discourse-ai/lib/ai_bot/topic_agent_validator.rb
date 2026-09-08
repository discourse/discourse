# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class TopicAgentValidator
      class << self
        def validate(topic, topic_creator)
          new(topic, topic_creator).validate
        end
      end

      def initialize(topic, topic_creator)
        @topic = topic
        @user = topic_creator.user
        @opts = topic_creator.opts
      end

      def validate
        validate_agent_field
        validate_agent_recipients if @topic.private_message?
      end

      private

      def validate_agent_field
        # in PostCreator opts, topic custom fields live under topic_opts and
        # are merged over the top-level (post) custom_fields at create time
        fields = @opts.dig(:topic_opts, :custom_fields) || @opts[:custom_fields]
        raw_agent_id = fields && (fields[TOPIC_AI_AGENT_ID_FIELD] || fields[:ai_agent_id])
        return if raw_agent_id.blank?

        raw_agent_id = raw_agent_id.to_s

        if raw_agent_id.bytesize > TOPIC_AI_AGENT_ID_MAX_LENGTH
          @topic.errors.add(
            :base,
            I18n.t(
              "custom_fields.validations.max_value_length",
              max_value_length: TOPIC_AI_AGENT_ID_MAX_LENGTH,
            ),
          )
          return
        end

        agent = accessible_agent(raw_agent_id.to_i) if raw_agent_id.match?(/\A-?\d+\z/)

        if agent.blank? || (@topic.private_message? && !agent.allow_personal_messages)
          @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
        end
      end

      # an agent's dedicated user can be targeted directly, bypassing the
      # custom field entirely, so the agent's PM policy must also be enforced
      # from the recipient side
      def validate_agent_recipients
        targeted_agents.each do |targeted_agent|
          agent = accessible_agent(targeted_agent.id)

          if agent.blank? || !agent.allow_personal_messages
            @topic.errors.add(:base, I18n.t("discourse_ai.ai_bot.errors.cannot_send_pm_to_agent"))
            break
          end
        end
      end

      def targeted_agents
        usernames = @opts[:target_usernames]
        user_ids = @opts[:target_user_ids]

        if usernames.present?
          usernames = usernames.split(",") if usernames.is_a?(String)
          AiAgent.joins(:user).where(
            users: {
              username_lower: usernames.map { |username| username.to_s.strip.downcase },
            },
          )
        elsif user_ids.present?
          AiAgent.where(user_id: user_ids)
        else
          AiAgent.none
        end
      end

      def accessible_agent(id)
        DiscourseAi::Agents::Agent.find_by(user: @user, id: id)
      end
    end
  end
end
