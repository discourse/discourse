# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryTagMapping < ActiveRecord::Base
    self.table_name = "data_explorer_query_tags"

    belongs_to :query, class_name: "DiscourseDataExplorer::Query"
    belongs_to :query_tag, class_name: "DiscourseDataExplorer::QueryTag"
  end
end

# == Schema Information
#
# Table name: data_explorer_query_tags
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  query_id     :bigint           not null
#  query_tag_id :bigint           not null
#
# Indexes
#
#  idx_data_explorer_query_tags_on_query_tag  (query_id,query_tag_id) UNIQUE
#  idx_data_explorer_query_tags_on_tag_query  (query_tag_id,query_id) UNIQUE
#
