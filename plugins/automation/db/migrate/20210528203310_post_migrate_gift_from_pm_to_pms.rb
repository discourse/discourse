# frozen_string_literal: true

class PostMigrateGiftFromPmToPms < ActiveRecord::Migration[6.1]
  def up
    query = DB.query(<<~SQL, name: "giftee_assignment_message")
      SELECT id, metadata
      FROM discourse_automation_fields
      WHERE name = :name
    SQL

    return if query.empty?

    query.each do |field|
      next if !field.metadata

      pm = field.metadata
      metadata = {
        pms: [
          {
            title: pm["title"],
            raw: pm["body"],
            delay: pm["delay"] || 0,
            prefers_encrypt: pm["encrypt"] || true,
          },
        ],
      }

      DB.exec(
        <<~SQL,
        UPDATE discourse_automation_fields
        SET name = :name, component = 'pms', metadata = :metadata
        WHERE id = :field_id
      SQL
        field_id: field.id,
        name: "giftee_assignment_messages",
        metadata: metadata.to_json,
      )
    end
  end
end
