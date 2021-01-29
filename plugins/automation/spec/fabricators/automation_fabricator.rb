# frozen_string_literal: true

Fabricator(:automation, from: DiscourseAutomation::Automation) do
  name 'Onboarding process'
  script 'send_pms'
end
