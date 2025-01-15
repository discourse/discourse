# frozen_string_literal: true

class ProblemCheck::AdminSidebarDeprecation < ProblemCheck::ProblemCheck
  self.priority = "low"

  def call
    return no_problem if SiteSetting.admin_sidebar_enabled_groups.present?

    problem
  end
end
