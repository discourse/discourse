# frozen_string_literal: true

class PopulateSolvedCategoryCustomFieldsFromSiteSettings < ActiveRecord::Migration[7.2]
  def up
    notify_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'notify_on_staff_accept_solved'",
      ).first

    if notify_value.nil?
      # this is the default value from settings.yml
      notify_value = false
    else
      notify_value = notify_value == "t"
    end

    empty_box_value =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'empty_box_on_unsolved'").first

    if empty_box_value.nil?
      # this is the default value from settings.yml
      empty_box_value = false
    else
      empty_box_value = empty_box_value == "t"
    end

    allow_solved_on_all =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'allow_solved_on_all_topics'",
      ).first

    if allow_solved_on_all.nil?
      # this is the default value from settings.yml
      allow_solved_on_all = false
    else
      allow_solved_on_all = allow_solved_on_all == "t"
    end

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

    DB.exec(<<~SQL, notify_value: notify_value)
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT solved_cats.category_id, 'notify_on_staff_accept_solved', :notify_value, NOW(), NOW()
      FROM (#{category_ids_sql}) solved_cats
      WHERE NOT EXISTS (
        SELECT 1 FROM category_custom_fields existing
        WHERE existing.category_id = solved_cats.category_id
          AND existing.name = 'notify_on_staff_accept_solved'
      )
    SQL

    DB.exec(<<~SQL, empty_box_value: empty_box_value)
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT solved_cats.category_id, 'empty_box_on_unsolved', :empty_box_value, NOW(), NOW()
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
