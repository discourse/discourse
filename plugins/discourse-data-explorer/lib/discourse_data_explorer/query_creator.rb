# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryCreator
    def self.create(query_params:, ai_description:, group_ids:, user:)
      name = query_params[:name].presence
      if name.blank?
        if AiQueryEnqueuer.enabled? && ai_description.present?
          name = I18n.t("discourse_data_explorer.ai.generating_name")
        else
          raise Discourse::InvalidParameters.new(:name)
        end
      end

      attrs = { name: name, user_id: user.id, last_run_at: Time.now }
      attrs[:description] = query_params[:description] if query_params[:description].present?
      attrs[:sql] = query_params[:sql] if query_params[:sql].present?

      query = Query.create!(attrs)

      group_ids&.each { |group_id| query.query_groups.find_or_create_by!(group_id: group_id) }

      AiQueryEnqueuer.enqueue(query: query, user: user, ai_description: ai_description)

      query
    end
  end
end
