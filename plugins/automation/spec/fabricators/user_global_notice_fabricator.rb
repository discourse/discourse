# frozen_string_literal: true

Fabricator(:user_global_notice, from: DiscourseAutomation::UserGlobalNotice) do
  user_id { Fabricate(:user).id }
  notice "This is an important notice"
  level "info"
  identifier "foo"
end
