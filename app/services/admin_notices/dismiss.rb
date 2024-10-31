# frozen_string_literal: true

class AdminNotices::Dismiss
  include Service::Base

  policy :invalid_access
  params do
    attribute :id, :integer

    validates :id, presence: true
  end
  model :admin_notice, optional: true
  transaction do
    step :destroy
    step :reset_problem_check
  end

  private

  def invalid_access(guardian:)
    guardian.is_admin?
  end

  def fetch_admin_notice(params:)
    AdminNotice.find_by(id: params.id)
  end

  def destroy(admin_notice:)
    return if admin_notice.blank?

    admin_notice.destroy!
  end

  def reset_problem_check(admin_notice:)
    return if admin_notice.blank?

    ProblemCheckTracker.find_by(identifier: admin_notice.identifier)&.reset
  end
end
