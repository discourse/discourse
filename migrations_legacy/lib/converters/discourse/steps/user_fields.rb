# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserFields < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM user_fields
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM user_fields
        ORDER BY id
      SQL
    end

    def process_item(item)
      IntermediateDB::UserField.create(
        original_id: item[:id],
        created_at: item[:created_at],
        description: item[:description],
        editable: item[:editable],
        external_name: item[:external_name],
        external_type: item[:external_type],
        field_type_enum: item[:field_type_enum],
        name: item[:name],
        position: item[:position],
        requirement: item[:requirement],
        searchable: item[:searchable],
        show_on_profile: item[:show_on_profile],
        show_on_user_card: item[:show_on_user_card],
      )
    end
  end
end
