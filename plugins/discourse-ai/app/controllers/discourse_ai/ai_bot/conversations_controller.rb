# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
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

        render json: {
                 conversations: serialize_data(pms, ListableTopicSerializer),
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
