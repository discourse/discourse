# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login

      def index
        page = params[:page].to_i
        per_page = params[:per_page]&.to_i || 40

        base_query =
          Topic
            .private_messages_for_user(current_user)
            .where(user: current_user) # Only show PMs where the current user is the author
            .joins(
              "INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id
                   AND tcf.name = '#{DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD}'
                   AND tcf.value = 't'",
            )
            .distinct

        total = base_query.count
        pms = base_query.order(last_posted_at: :desc).offset(page * per_page).limit(per_page)

        serialized = serialize_data(pms, ListableTopicSerializer)

        agent_fields =
          TopicCustomField.where(topic_id: pms.map(&:id), name: %w[ai_agent ai_agent_id]).pluck(
            :topic_id,
            :name,
            :value,
          )

        agent_ids = agent_fields.filter_map { |_, n, v| v.to_i if n == "ai_agent_id" && v.present? }
        agents_by_id =
          if agent_ids.present?
            AiAgent.where(id: agent_ids).pluck(:id, :name).to_h
          else
            {}
          end

        agent_names = {}
        agent_fields.each do |topic_id, name, value|
          next if agent_names[topic_id]
          if name == "ai_agent_id" && value.present?
            agent_names[topic_id] = agents_by_id[value.to_i]
          elsif name == "ai_agent"
            agent_names[topic_id] ||= value
          end
        end

        serialized.each { |s| s[:ai_agent_name] = agent_names[s[:id]] }

        render json: {
                 conversations: serialized,
                 meta: {
                   total: total,
                   page: page,
                   per_page: per_page,
                   has_more: total > (page + 1) * per_page,
                 },
               }
      end
    end
  end
end
