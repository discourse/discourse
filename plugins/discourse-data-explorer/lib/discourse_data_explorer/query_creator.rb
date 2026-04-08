# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryCreator
    def self.create(query_params:, group_ids:, user:)
      name = query_params[:name].presence
      raise Discourse::InvalidParameters.new(:name) if name.blank?

      attrs = { name: name, user_id: user.id, last_run_at: Time.now }
      attrs[:description] = query_params[:description] if query_params[:description].present?
      attrs[:sql] = query_params[:sql] if query_params[:sql].present?

      query = Query.create!(attrs)

      group_ids&.each { |group_id| query.query_groups.find_or_create_by!(group_id: group_id) }

      query
    end
  end
end
