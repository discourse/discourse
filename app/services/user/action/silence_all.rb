# frozen_string_literal: true

class User::Action::SilenceAll < Service::ActionBase
  option :users, []
  option :actor
  option :params
  option :raise_on_failure, default: -> { false }

  delegate :message, :post_id, :silenced_till, :reason, :reviewable_id, to: :params, private: true

  attr_reader :restrictions

  def call
    @restrictions = []
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
          message_body: message,
          keep_posts: true,
          silenced_till:,
          reason:,
          post_id:,
          reviewable_id:,
        )
        .tap do |silencer|
          unless silencer.silence
            raise ActiveRecord::RecordInvalid.new(user) if raise_on_failure
            next
          end
          @restrictions << Reviewable::Restriction.new(
            kind: :silenced,
            target: user,
            expires_at: user.silenced_till,
          )
          Jobs.enqueue(
            :critical_user_email,
            type: "account_silenced",
            user_id: user.id,
            user_history_id: silencer.user_history.id,
          )
        end
    rescue => err
      raise if raise_on_failure
      Discourse.warn_exception(err, message: "failed to silence user with ID #{user.id}")
    end
  end
end
