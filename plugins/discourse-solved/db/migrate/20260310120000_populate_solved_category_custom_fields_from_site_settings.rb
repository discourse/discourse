# frozen_string_literal: true

class PopulateSolvedCategoryCustomFieldsFromSiteSettings < ActiveRecord::Migration[7.2]
  def up
    notify_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'notify_on_staff_accept_solved'",
      ).first

    empty_box_value =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'empty_box_on_unsolved'").first

    # Convert DB stored "t"/"f" to the "true"/"false" strings used by category custom fields.
    # If the setting doesn't exist in the DB, it was never changed from default (false).
    notify_cf_value = notify_value == "t" ? "true" : "false"
    empty_box_cf_value = empty_box_value == "t" ? "true" : "false"

    allow_solved_on_all =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'allow_solved_on_all_topics'",
      ).first == "t"

    # When allow_solved_on_all_topics is enabled, every category can have solved topics,
    # so populate custom fields for all categories. Otherwise only populate for categories
    # that have enable_accepted_answers set.
    category_ids_sql =
      if allow_solved_on_all
        "SELECT id AS category_id FROM categories"
      else
        <<~SQL
          SELECT category_id FROM category_custom_fields
          WHERE name = 'enable_accepted_answers' AND value = 'true'
        SQL
      end

    execute <<~SQL
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT solved_cats.category_id, 'notify_on_staff_accept_solved', #{ActiveRecord::Base.connection.quote(notify_cf_value)}, NOW(), NOW()
      FROM (#{category_ids_sql}) solved_cats
      WHERE NOT EXISTS (
        SELECT 1 FROM category_custom_fields existing
        WHERE existing.category_id = solved_cats.category_id
          AND existing.name = 'notify_on_staff_accept_solved'
      )
    SQL

    execute <<~SQL
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT solved_cats.category_id, 'empty_box_on_unsolved', #{ActiveRecord::Base.connection.quote(empty_box_cf_value)}, NOW(), NOW()
      FROM (#{category_ids_sql}) solved_cats
      WHERE NOT EXISTS (
        SELECT 1 FROM category_custom_fields existing
        WHERE existing.category_id = solved_cats.category_id
          AND existing.name = 'empty_box_on_unsolved'
      )
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM category_custom_fields
      WHERE name IN ('notify_on_staff_accept_solved', 'empty_box_on_unsolved')
    SQL
  end
end
