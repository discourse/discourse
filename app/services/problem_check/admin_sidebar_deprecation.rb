# frozen_string_literal: true

class ProblemCheck::AdminSidebarDeprecation < ProblemCheck::ProblemCheck
  self.priority = "low"

  def call
    if SiteSetting.admin_sidebar_enabled_groups.present? &&
         SiteSetting.admin_sidebar_enabled_groups != "-1"
      return no_problem
    end

    problem
  end
end
