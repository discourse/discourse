# frozen_string_literal: true

DiscourseAutomation::Triggerable::POINT_IN_TIME = 'point_in_time'

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::POINT_IN_TIME) do
  on_update do |automation, metadata|
    automation
      .pending_automations
      .create!(execute_at: metadata[:execute_at])
  end
end
