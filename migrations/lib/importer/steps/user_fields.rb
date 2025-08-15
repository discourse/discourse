# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserFields < ::Migrations::Importer::CopyStep
    include ::HasSanitizableFields

    SANITIZER_ATTRIBUTES = %w[target].freeze
    DEFAULT_POSITION = 0
    REQUIREMENTS = UserField.requirements.values.to_set.freeze
    DEFAULT_REQUIREMENT = UserField.requirements[:optional]
    REQUIRED_FOR_ALL = UserField.requirements[:for_all_users]
    FIELD_TYPES = UserField.field_type_enums.values.to_set.freeze
    DEFAULT_FIELD_TYPE = UserField.field_type_enums[:text]

    requires_mapping :existing_user_field_by_name, "SELECT LOWER(name), id FROM user_fields"

    column_names %i[
                   id
                   created_at
                   description
                   editable
                   external_name
                   external_type
                   field_type_enum
                   name
                   position
                   requirement
                   searchable
                   show_on_profile
                   show_on_user_card
                   updated_at
                 ]

    store_mapped_ids true

    total_rows_query <<~SQL, MappingType::USER_FIELDS
      SELECT COUNT(*)
      FROM user_fields
           LEFT JOIN mapped.ids mapped_user_field
             ON user_fields.original_id = mapped_user_field.original_id
                AND mapped_user_field.type = ?
      WHERE mapped_user_field.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::USER_FIELDS
      SELECT user_fields.*
      FROM user_fields
           LEFT JOIN mapped.ids mapped_user_field
             ON user_fields.original_id = mapped_user_field.original_id
                AND mapped_user_field.type = ?
      WHERE mapped_user_field.original_id IS NULL
      ORDER BY user_fields.original_id
    SQL

    def initialize(intermediate_db, discourse_db, shared_data)
      super

      @required_fields_version_bumped = false
    end

    private

    def transform_row(row)
      name = row[:name]
      name_lower = name.downcase

      if (existing_id = @existing_user_field_by_name[name_lower])
        row[:id] = existing_id

        return nil
      end

      description = row[:description]

      if description.empty?
        puts "    User field '#{name}' description cannot be empty"

        return nil
      end

      row[:editable] ||= false
      row[:show_on_profile] ||= false
      row[:show_on_user_card] ||= false
      row[:searchable] ||= false

      row[:position] ||= DEFAULT_POSITION
      row[:description] = sanitize_field(description, additional_attributes: SANITIZER_ATTRIBUTES)

      row[:requirement] = ensure_valid_value(
        value: row[:requirement],
        allowed_set: REQUIREMENTS,
        default_value: DEFAULT_REQUIREMENT,
      )
      row[:field_type_enum] = ensure_valid_value(
        value: row[:field_type_enum],
        allowed_set: FIELD_TYPES,
        default_value: DEFAULT_FIELD_TYPE,
      )

      super
    end

    def after_commit_of_inserted_rows(rows)
      super

      if !@required_fields_version_bumped &&
           rows.any? { |row| row[:requirement] == REQUIRED_FOR_ALL }
        DB.exec(<<~SQL)
          INSERT INTO user_required_fields_versions (created_at, updated_at)
          VALUES (NOW(), NOW())
        SQL

        @required_fields_version_bumped = true
      end
    end
  end
end
