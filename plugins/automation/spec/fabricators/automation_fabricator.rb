# frozen_string_literal: true

Fabricator(:automation, from: DiscourseAutomation::Automation) do
  name 'Onboarding process'
  script 'send_pms'
  last_updated_by_id Discourse.system_user.id
end
