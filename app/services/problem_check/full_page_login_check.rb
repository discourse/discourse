# frozen_string_literal: true

class ProblemCheck::FullPageLoginCheck < ProblemCheck
  self.priority = "low"

  def call
    if full_page_login_disabled?
      return problem(override_key: "dashboard.problem.full_page_login_check")
    end

    no_problem
  end

  private

  def full_page_login_disabled?
    SiteSetting.full_page_login == false
  end
end
