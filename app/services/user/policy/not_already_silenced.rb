# frozen_string_literal: true

class User::Policy::NotAlreadySilenced < Service::PolicyBase
  delegate :user, to: :context, private: true
  delegate :silenced_record, to: :user, private: true

  def call
    !user.silenced?
  end

  def reason
    # The log is missing when the penalty history was reset or the silence was
    # applied through an anonymous shadow, and its acting user when they were
    # deleted.
    record = silenced_record
    staff = record&.acting_user
    return I18n.t("user.already_silenced_without_details") if staff.nil?

    I18n.t(
      "user.already_silenced",
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
