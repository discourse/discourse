# frozen_string_literal: true

class AdminNotices::Dismiss
  include Service::Base

  model :admin_notice

  policy :invalid_access

  transaction do
    step :destroy
    step :reset_problem_check
  end

  private

  def fetch_admin_notice(id:)
    AdminNotice.find_by(id: id)
  end

  def invalid_access(guardian:)
    guardian.is_admin?
  end

  def destroy(admin_notice:)
    admin_notice.destroy!
  end

  def reset_problem_check(admin_notice:)
    ProblemCheckTracker.find_by(identifier: admin_notice.identifier)&.reset
  end
end
