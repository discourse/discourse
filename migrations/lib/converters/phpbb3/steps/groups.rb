# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class Groups < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL, group_type_special: Constants::GROUP_TYPE_SPECIAL)
        SELECT COUNT(*)
        FROM phpbb_groups
        WHERE group_type <> :group_type_special
      SQL
    end

    def items
      query(<<~SQL, group_type_special: Constants::GROUP_TYPE_SPECIAL)
        SELECT g.group_id, g.group_type, g.group_name, g.group_desc
        FROM phpbb_groups g
        WHERE g.group_type <> :group_type_special
        ORDER BY g.group_id
      SQL
    end

    def process_item(item)
      IntermediateDB::Group.create(
        original_id: item[:group_id],
        name: sanitize_group_name(item[:group_name]),
        full_name: item[:group_name],
        bio_raw: item[:group_desc],
      )
    end

    private

    def sanitize_group_name(name)
      name.to_s[0..19].gsub(/[^a-zA-Z0-9\-_. ]/, "_")
    end
  end
end
