# frozen_string_literal: true

Fabricator(:user_history) { acting_user { Fabricate(:user) } }

Fabricator(:site_setting_change_history, from: :user_history) do
  action { UserHistory.actions[:change_site_setting] }
  previous_value { "old value" }
  new_value { "new value" }
  subject { "some_site_setting" }
end

Fabricator(:topic_closed_change_history, from: :user_history) do
  action { UserHistory.actions[:topic_closed] }
  subject { "some_site_setting" }
  topic_id { Fabricate(:topic).id }
end
