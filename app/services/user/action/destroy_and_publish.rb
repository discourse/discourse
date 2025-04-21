# frozen_string_literal: true

class User::Action::DestroyAndPublish < Service::ActionBase
  option :user
  option :position
  option :guardian
  option :total_size
  option :block_ip_and_email, default: proc { false }

  delegate :ip_address, to: :actor, prefix: true, private: true

  def call
    data = { position:, username: user.username, total: total_size }
    ::MessageBus.publish("/bulk-user-delete", data.merge(destroy_user!), user_ids: [actor.id])
  end

  private

  def actor
    guardian.user
  end

  def destroy_user!
    success =
      UserDestroyer.new(actor).destroy(
        user,
        delete_posts: true,
        prepare_for_destroy: true,
        context: I18n.t("staff_action_logs.bulk_user_delete"),
        block_ip: block_ip_and_email && actor_ip_address != user.ip_address,
        block_email: block_ip_and_email,
      )
    return { success: true } if success
    { failed: true, error: user.errors.full_messages.join(", ") }
  rescue => err
    { failed: true, error: err.message }
  end
end
