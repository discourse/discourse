# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class GroupUsers < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    run_in_parallel(true)

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL)
        SELECT COUNT(DISTINCT group_id, user_id)
        FROM phpbb_user_group
      SQL
    end

    def items
      query(<<~SQL)
        SELECT ug.group_id, ug.user_id, MAX(ug.group_leader) AS group_leader
        FROM phpbb_user_group ug
        GROUP BY ug.group_id, ug.user_id
        ORDER BY ug.group_id, ug.user_id
      SQL
    end

    def process_item(item)
      IntermediateDB::GroupUser.create(
        group_id: item[:group_id],
        user_id: item[:user_id],
        owner: item[:group_leader] == 1,
      )
    end
  end
end
