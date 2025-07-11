# frozen_string_literal: true

module ::DiscourseDataExplorer
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

    def params
      @params ||= Parameter.create_from_sql(sql)
    end

    def cast_params(input_params)
      result = {}.with_indifferent_access
      self.params.each do |pobj|
        result[pobj.identifier] = pobj.cast_to_ruby input_params[pobj.identifier]
      end
      result
    end

    def slug
      Slug.for(name).presence || "query-#{id}"
    end

    def self.find(id)
      return super if id.to_i >= 0
      QueryFinder.find(id)
    end

    private

    # for `Query.unscoped.find`
    class ActiveRecord_Relation
      def find(id)
        return super if id.to_i >= 0
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
#  name        :string
#  description :text
#  sql         :text             default("SELECT 1"), not null
#  user_id     :integer
#  last_run_at :datetime
#  hidden      :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
