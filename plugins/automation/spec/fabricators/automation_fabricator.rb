# frozen_string_literal: true

Fabricator(:automation, from: DiscourseAutomation::Automation) do
  name "My Automation"
  script "something_about_us"
  trigger DiscourseAutomation::Triggers::TOPIC
  last_updated_by_id Discourse.system_user.id
  enabled true
end
