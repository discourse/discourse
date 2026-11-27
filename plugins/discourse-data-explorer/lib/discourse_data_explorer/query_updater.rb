# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryUpdater
    def self.update(query:, query_params:, group_ids: nil)
      query_params = query_params.to_h.symbolize_keys
      sql_changed = query_params.key?(:sql) && query.sql != query_params[:sql]
      tag_names = query_params.delete(:tags)

      Query.transaction do
        query.update!(query_params.merge(hidden: false))
        QueryTag.sync!(query:, names: tag_names) unless tag_names.nil?

        unless group_ids.nil?
          query.query_groups.where.not(group_id: group_ids).delete_all
          group_ids.each { |group_id| query.query_groups.find_or_create_by!(group_id:) }
        end
      end

      DB.after_commit { QueryRunner.invalidate(query.id) } if sql_changed
      query
    end
  end
end
