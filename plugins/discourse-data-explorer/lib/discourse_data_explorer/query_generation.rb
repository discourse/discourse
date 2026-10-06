# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryGeneration
    Error = Class.new(StandardError)

    def self.call(user:, ai_description:, existing_sql: nil)
      raise Discourse::InvalidAccess unless user&.admin?
      unless SiteSetting.data_explorer_enabled && SiteSetting.discourse_ai_enabled &&
               SiteSetting.data_explorer_ai_queries_enabled
        raise Discourse::InvalidAccess
      end
      raise Discourse::InvalidParameters.new(:ai_description) if ai_description.blank?

      agent_id = DiscourseAi::Agents::Agent.external_agent_id(AiQueryGenerator)
      agent_record = AiAgent.find_by(id: agent_id)
      if agent_record.nil?
        raise Error.new(
                I18n.t("discourse_data_explorer.ai.error_agent_not_configured"),
              )
      end

      bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_record.class_instance.new)
      user_message = ai_description
      if existing_sql.present?
        user_message =
          "#{ai_description}\n\nHere is the current SQL query to refine:\n```sql\n#{existing_sql}\n```"
      end
      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: user_message }],
          user: user,
          feature_name: "data_explorer_query_generation",
        )
      bot.reply(context)
      parsed = context.feature_context[Tools::SubmitQuery::CONTEXT_KEY] || {}
      if parsed[:sql].blank?
        raise Error.new(
                I18n.t("discourse_data_explorer.ai.error_no_sql_returned"),
              )
      end
      {
        sql: parsed[:sql].chomp(";").strip,
        name: parsed[:name].presence || ai_description.to_s.truncate(60, separator: " "),
        description: parsed[:description].presence || ai_description,
      }
    end
  end
end
