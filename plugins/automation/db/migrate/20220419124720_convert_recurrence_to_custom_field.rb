# frozen_string_literal: true

class ConvertRecurrenceToCustomField < ActiveRecord::Migration[6.1]
  def change
    DB
      .query("SELECT id,metadata FROM discourse_automation_fields WHERE name = 'recurrence'")
      .each do |field|
        old_value = field.metadata["value"]
        next unless old_value.is_a? String

        interval = 1
        frequency = old_value.sub("every_", "")

        if frequency == "other_week"
          interval = 2
          frequency = "week"
        end

        new_value = { interval: interval, frequency: frequency }
        metadata = { value: new_value }.to_json

        DB.exec(<<~SQL, field_id: field.id, metadata: metadata)
        UPDATE discourse_automation_fields
        SET metadata = :metadata, component = 'period'
        WHERE id = :field_id
      SQL
      end
  end
end
