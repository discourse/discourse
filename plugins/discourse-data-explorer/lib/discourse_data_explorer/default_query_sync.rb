# frozen_string_literal: true

module DiscourseDataExplorer
  class DefaultQuerySync
    def self.execute
      Queries.default.each_value { new(it).execute }
    end

    def initialize(definition)
      @attributes = definition.merge("user_id" => Discourse::SYSTEM_USER_ID)
    end

    def execute
      query.with_lock do
        query.update!(attributes)
        invalidate_cached_results if query.saved_change_to_sql?
      end
    end

    private

    attr_reader :attributes

    def query
      @query ||=
        Query.find_or_create_by!(id: attributes.fetch("id")) { it.assign_attributes(attributes) }
    end

    def invalidate_cached_results
      ActiveRecord.after_all_transactions_commit { QueryRunner.invalidate(query.id) }
    end
  end
end
