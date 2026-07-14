# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryFinder
    def self.find(id)
      default_query = Queries.default[id.to_s]
      return raise ActiveRecord::RecordNotFound unless default_query

      query = Query.find_by(id: id) || Query.new
      query.attributes = default_query
      query.user_id = Discourse::SYSTEM_USER_ID.to_s
      query
    end
  end

  class Query < ActiveRecord::Base
    self.table_name = "data_explorer_queries"

    has_many :query_groups
    has_many :groups, through: :query_groups
    belongs_to :user
    validates :name, presence: true

    scope :for_group,
          ->(group) do
            where(hidden: false).joins(
              "INNER JOIN data_explorer_query_groups
              ON data_explorer_query_groups.query_id = data_explorer_queries.id
              AND data_explorer_query_groups.group_id = #{group.id}",
            )
          end

    scope :user_queries, -> { where(hidden: false).where("id > 0") }

    def self.is_default_query?(id)
      id.to_i < 0
    end

    def params
      @params ||= Parameter.create_from_sql(sql)
    end

    def cast_params(input_params, opts = {})
      result = {}.with_indifferent_access
      params.each do |pobj|
        result[pobj.identifier] = pobj.cast_to_ruby(input_params[pobj.identifier], opts)
      end
      result
    end

    def slug
      Slug.for(name).presence || "query-#{id}"
    end

    def record_run!
      persisted? ? update_columns(last_run_at: Time.now) : update!(last_run_at: Time.now)
      DiscourseDataExplorer::QueryStat.log(id) unless Query.is_default_query?(id)
    end

    def self.find(id)
      return super unless is_default_query?(id)
      QueryFinder.find(id)
    end

    def self.unpersisted_defaults(search: nil)
      persisted_ids = where(hidden: false).where("id < 0").pluck(:id).to_set
      query_text = search&.downcase

      Queries.default.filter_map do |_, attributes|
        next if persisted_ids.include?(attributes["id"])

        if query_text
          name_match = attributes["name"]&.downcase&.include?(query_text)
          desc_match = attributes["description"]&.downcase&.include?(query_text)
          next unless name_match || desc_match
        end

        record = new(attributes.slice("id", "sql", "name", "description"))
        record.user_id = Discourse::SYSTEM_USER_ID.to_s
        record
      end
    end

    private

    # for `Query.unscoped.find`
    class ActiveRecord_Relation
      def find(id)
        return super unless Query.is_default_query?(id)
        QueryFinder.find(id)
      end
    end
  end
end

# == Schema Information
#
# Table name: data_explorer_queries
#
#  id          :bigint           not null, primary key
#  description :text
#  hidden      :boolean          default(FALSE), not null
#  last_run_at :datetime
#  name        :string
#  sql         :text             default("SELECT 1"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer
#
