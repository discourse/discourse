# frozen_string_literal: true

class ConvertDateComponentToDateTime < ActiveRecord::Migration[6.1]
  def change
    DB
      .query("SELECT id,metadata FROM discourse_automation_fields WHERE component = 'date'")
      .each do |field|
        metadata = { value: field.metadata["date"] }.to_json
        DB.exec(<<~SQL, field_id: field.id, metadata: metadata)
        UPDATE discourse_automation_fields
        SET metadata = :metadata, component = 'date_time'
        WHERE id = :field_id
      SQL
      end
  end
end
