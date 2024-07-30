# frozen_string_literal: true

class ChangeUserGroupMembershipThroughBadgeScriptBadgeNameFieldToBadge < ActiveRecord::Migration[
  7.0
]
  def change
    query = <<~SQL
      SELECT
        f.id,
        b.id AS badge_id
      FROM
        discourse_automation_fields f
      INNER JOIN  discourse_automation_automations a ON a.id = f.automation_id
      INNER JOIN badges b ON b.name = TRIM(BOTH ' ' FROM f.metadata->>'value')
      WHERE
        f.name = 'badge_name'
        AND  a.script = 'user_group_membership_through_badge'
    SQL

    DB
      .query(query)
      .each do |field|
        metadata = { value: field.badge_id }.to_json

        DB.exec(<<~SQL, field_id: field.id, metadata: metadata)
        UPDATE discourse_automation_fields
        SET metadata = :metadata, component = 'choices', name = 'badge'
        WHERE id = :field_id
      SQL
      end
  end
end
