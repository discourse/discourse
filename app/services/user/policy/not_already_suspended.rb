# frozen_string_literal: true

class User::Policy::NotAlreadySuspended < Service::PolicyBase
  delegate :user, to: :context, private: true
  delegate :suspend_record, to: :user, private: true

  def call
    !user.suspended?
  end

  def reason
    # The log is missing when the penalty history was reset or the suspension
    # was copied onto an anonymous shadow, and its acting user when they were
    # deleted.
    record = suspend_record
    staff = record&.acting_user
    return I18n.t("user.already_suspended_without_details") if staff.nil?

    I18n.t(
      "user.already_suspended",
      staff: staff.username,
      time_ago:
        AgeWords.time_ago_in_words(
          record.created_at,
          true,
          scope: :"datetime.distance_in_words_verbose",
        ),
    )
  end
end
