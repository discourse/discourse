# frozen_string_literal: true

class User::Action::SilenceAll < Service::ActionBase
  option :users, []
  option :actor
  option :params
  option :raise_on_failure, default: -> { false }

  delegate :message,
           :post_id,
           :silenced_till,
           :reason,
           :reason_is_preset,
           :reviewable_id,
           to: :params,
           private: true

  def call
    silenced_users.first.try(:user_history).try(:details)
  end

  private

  def silenced_users
    users.map do |user|
      next if raise_on_failure && user.silenced?

      UserSilencer
        .new(
          user,
          actor,
          message: :moderator_silence,
          message_body: message,
          keep_posts: true,
          silenced_till:,
          reason:,
          reason_is_preset:,
          post_id:,
          reviewable_id:,
        )
        .tap do |silencer|
          raise ActiveRecord::RecordInvalid.new(user) if !silencer.silence && raise_on_failure
        end
    rescue => err
      raise if raise_on_failure
      Discourse.warn_exception(err, message: "failed to silence user with ID #{user.id}")
    end
  end
end
