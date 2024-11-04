# frozen_string_literal: true

class User::Action::SilenceAll < Service::ActionBase
  option :users, []
  option :actor
  option :params

  delegate :message, :post_id, :silenced_till, :reason, to: :params, private: true

  def call
    silenced_users.first.try(:user_history).try(:details)
  end

  private

  def silenced_users
    users.map do |user|
      UserSilencer
        .new(
          user,
          actor,
          message_body: message,
          keep_posts: true,
          silenced_till:,
          reason:,
          post_id:,
        )
        .tap do |silencer|
          next unless silencer.silence
          Jobs.enqueue(
            :critical_user_email,
            type: "account_silenced",
            user_id: user.id,
            user_history_id: silencer.user_history.id,
          )
        end
    rescue => err
      Discourse.warn_exception(err, message: "failed to silence user with ID #{user.id}")
    end
  end
end
