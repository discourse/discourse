# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryStat < ActiveRecord::Base
    self.table_name = "data_explorer_query_stats"

    scope :for_user_queries, -> { where("query_id > 0") }

    def self.log(query_id, date: Date.current)
      DB.exec(<<~SQL, query_id: query_id, date: date)
        INSERT INTO data_explorer_query_stats (query_id, date, total_runs)
        VALUES (:query_id, :date, 1)
        ON CONFLICT (query_id, date)
        DO UPDATE SET total_runs = data_explorer_query_stats.total_runs + 1
      SQL
    end
  end
end

# == Schema Information
#
# Table name: data_explorer_query_stats
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  total_runs :integer          default(0), not null
#  query_id   :bigint           not null
#
# Indexes
#
#  index_data_explorer_query_stats_on_query_id_and_date  (query_id,date) UNIQUE
#
