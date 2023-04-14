# frozen_string_literal: true

DiscourseAutomation::Scriptable::SUSPEND_USER_BY_EMAIL = "suspend_user_by_email"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::SUSPEND_USER_BY_EMAIL) do
  version 1

  triggerables %i[api_call]

  field :reason, component: :text, required: true
  field :suspend_until, component: :date_time, required: true
  field :actor, component: :user

  script do |context, fields|
    email = context["email"]
    next unless target = UserEmail.find_by(email: email)&.user

    next if target.suspended?

    unless actor =
             User.find_by(username: fields.dig("actor", "value") || Discourse.system_user.username)
      next
    end
    guardian = Guardian.new(actor)
    guardian.ensure_can_suspend!(target)

    suspend_until = context["suspend_until"].presence || fields.dig("suspend_until", "value")
    reason = context["reason"].presence || fields.dig("reason", "value")

    User.transaction do
      target.suspended_till = suspend_until
      target.suspended_at = DateTime.now
      target.save!

      StaffActionLogger.new(actor).log_user_suspend(target, reason)
    end
  end
end
