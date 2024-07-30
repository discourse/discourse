# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::POINT_IN_TIME) do
  field :execute_at, component: :date_time, required: true

  on_update do |automation, fields, previous_fields|
    execute_at = fields.dig("execute_at", "value")
    previous_execute_at = previous_fields&.dig("execute_at", "value")

    if execute_at != previous_execute_at
      automation.pending_automations.destroy_all

      # prevents creating a new pending automation on save when date is expired
      if execute_at && execute_at > Time.zone.now
        automation.pending_automations.create!(execute_at: execute_at)
      end
    end
  end
end
