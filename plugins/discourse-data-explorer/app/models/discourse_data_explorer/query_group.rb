# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryGroup < ActiveRecord::Base
    self.table_name = "data_explorer_query_groups"

    belongs_to :query
    belongs_to :group

    has_many :bookmarks, as: :bookmarkable
  end
end

# == Schema Information
#
# Table name: data_explorer_query_groups
#
#  id       :bigint           not null, primary key
#  query_id :bigint
#  group_id :integer
#
# Indexes
#
#  index_data_explorer_query_groups_on_group_id               (group_id)
#  index_data_explorer_query_groups_on_query_id               (query_id)
#  index_data_explorer_query_groups_on_query_id_and_group_id  (query_id,group_id) UNIQUE
#
