# frozen_string_literal: true

# Publishers only meet a readiness problem when they try to publish, and they may
# not be able to change settings, so admins are told on the dashboard.
class ProblemCheck::BlogNotReady < ProblemCheck
  self.priority = "high"

  def call
    return no_problem if !blog_in_use?
    blocker = Blog::Instance.cached.lazy.filter_map { Blog::Readiness.new(_1).problems.first }.first
    return no_problem if blocker.nil?
    setting = blocker.settings.first
    return problem(override_data: { reason: blocker.message, setting: }) if setting

    problem(
      override_key: "dashboard.problem.blog_not_ready_without_setting",
      override_data: {
        reason: blocker.message,
      },
    )
  end

  private

  # The blog is switched on for sites that never asked for it, and they should not
  # be warned about a feature nobody has used.
  def blog_in_use?
    SiteSetting.blog_drafts_category.present? || Blog::Publication.exists?
  end
end
