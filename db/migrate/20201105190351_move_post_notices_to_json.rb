# frozen_string_literal: true

class MovePostNoticesToJson < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      INSERT INTO post_custom_fields(post_id, name, value, created_at, updated_at)
      SELECT
        posts.id,
        'notice',
        CASE
          WHEN pcf_type.value = 'custom'         THEN json_build_object('type', pcf_type.value, 'raw', pcf_args.value, 'cooked', pcf_args.value)
          WHEN pcf_type.value = 'new_user'       THEN json_build_object('type', pcf_type.value)
          WHEN pcf_type.value = 'returning_user' THEN json_build_object('type', pcf_type.value, 'last_posted_at', pcf_args.value)
        END,
        pcf_type.created_at created_at,
        pcf_type.updated_at updated_at
      FROM posts
      JOIN post_custom_fields pcf_type ON posts.id = pcf_type.post_id AND pcf_type.name = 'notice_type'
      LEFT JOIN post_custom_fields pcf_args ON posts.id = pcf_args.post_id AND pcf_args.name = 'notice_args'
    SQL

    execute "DELETE FROM post_custom_fields WHERE name = 'notice_type' OR name = 'notice_args'"

    add_index :post_custom_fields,
              :post_id,
              unique: true,
              name: "index_post_custom_fields_on_notice",
              where: "name = 'notice'"

    remove_index :post_custom_fields, name: "index_post_custom_fields_on_notice_type"
    remove_index :post_custom_fields, name: "index_post_custom_fields_on_notice_args"
  end

  def down
    execute <<~SQL
      INSERT INTO post_custom_fields(post_id, name, value, created_at, updated_at)
      SELECT post_id, 'notice_type', value::json->>'type', created_at, updated_at
      FROM post_custom_fields
      WHERE name = 'notice'
    SQL

    execute <<~SQL
      INSERT INTO post_custom_fields(post_id, name, value, created_at, updated_at)
      SELECT post_id, 'notice_args', COALESCE(value::json->>'cooked', value::json->>'last_posted_at'), created_at, updated_at
      FROM post_custom_fields
      WHERE name = 'notice'
    SQL

    execute "DELETE FROM post_custom_fields WHERE name = 'notice'"

    add_index :post_custom_fields,
              :post_id,
              unique: true,
              name: "index_post_custom_fields_on_notice_type",
              where: "name = 'notice_type'"
    add_index :post_custom_fields,
              :post_id,
              unique: true,
              name: "index_post_custom_fields_on_notice_args",
              where: "name = 'notice_args'"

    remove_index :index_post_custom_fields_on_notice
  end
end
