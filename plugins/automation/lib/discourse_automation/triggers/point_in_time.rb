# frozen_string_literal: true

DiscourseAutomation::Triggerable::POINT_IN_TIME = "point_in_time"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::POINT_IN_TIME) do
  field :execute_at, component: :date_time, required: true

  on_update do |automation, metadata|
    # prevents creating a new pending automation on save when date is expired
    execute_at = metadata.dig("execute_at", "value")
    if execute_at && execute_at > Time.zone.now
      automation.pending_automations.create!(execute_at: execute_at)
    end
  end
end
