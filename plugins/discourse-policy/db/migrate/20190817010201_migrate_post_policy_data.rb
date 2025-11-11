# frozen_string_literal: true

class MigratePostPolicyData < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      INSERT INTO post_policies(
        post_id,
        group_id,
        version,
        reminder,
        last_reminded_at,
        renew_days,
        updated_at,
        created_at
      )
      SELECT
        f1.post_id,
        (select id from groups where name ilike f1.value) group_id,
        f2.value as version,
        f3.value as reminder,
        case when f4.value ~ '^[0-9]+$' then
          TIMESTAMP 'epoch' + f4.value::integer * interval '1 second'
          else null end
        as last_reminded_at,
        case when f5.value ~ '^[0-9]+$' then
           f5.value::integer else null end
        as renew_days,
        greatest(f1.updated_at, f2.updated_at) as updated_at,
        least(f1.updated_at, f2.updated_at) as created_at
      FROM post_custom_fields f1
      LEFT JOIN post_custom_fields f2 ON
        f1.post_id = f2.post_id AND f2.name = 'PolicyVersion'
      LEFT JOIN post_custom_fields f3 ON
        f1.post_id = f3.post_id AND f3.name = 'PolicyReminder'
      LEFT JOIN post_custom_fields f4 ON
        f1.post_id = f4.post_id AND f4.name = 'LastRemindedAt'
      LEFT JOIN post_custom_fields f5 ON
        f1.post_id = f5.post_id AND f5.name = 'PolicyRenewDays'
      WHERE f1.name = 'PolicyGroup'
      AND  (select id from groups where name ilike f1.value) is not null
      ON CONFLICT DO NOTHING
    SQL

    execute(<<~SQL)
      INSERT INTO post_custom_fields (post_id, name, value, created_at, updated_at)
      SELECT post_id, 'HasPolicy', 'true', created_at, updated_at
      FROM post_policies
    SQL

    execute(<<~SQL)
      DELETE FROM post_custom_fields
      WHERE name in (
        'PolicyGroup',
        'PolicyVersion',
        'PolicyReminder',
        'PolicyRemindedAt',
        'PolicyRenewDays'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
