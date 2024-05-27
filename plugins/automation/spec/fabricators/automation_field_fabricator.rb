# frozen_string_literal: true

Fabricator(:automation_field, from: DiscourseAutomation::Field) do
  automation
  name "custom_field_name"
  component "custom_field"
end
