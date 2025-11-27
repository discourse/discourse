# frozen_string_literal: true

class User::Policy::IsAdmin < Service::PolicyBase
  delegate :guardian, to: :context

  def call
    guardian.is_admin?
  end

  def reason
  end
end
