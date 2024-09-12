# frozen_string_literal: true

class User::Policy::NotAlreadySilenced < Service::PolicyBase
  delegate :user, to: :context, private: true
  delegate :silenced_record, to: :user, private: true

  def call
    !user.silenced?
  end

  def reason
    I18n.t(
      "user.already_silenced",
      staff: silenced_record.acting_user.username,
      time_ago:
        AgeWords.time_ago_in_words(
          silenced_record.created_at,
          true,
          scope: :"datetime.distance_in_words_verbose",
        ),
    )
  end
end
