# frozen_string_literal: true

class User::Policy::NotAlreadySuspended < Service::PolicyBase
  delegate :user, to: :context, private: true
  delegate :suspend_record, to: :user, private: true

  def call
    !user.suspended?
  end

  def reason
    I18n.t(
      "user.already_suspended",
      staff: suspend_record.acting_user.username,
      time_ago:
        AgeWords.time_ago_in_words(
          suspend_record.created_at,
          true,
          scope: :"datetime.distance_in_words_verbose",
        ),
    )
  end
end
