# frozen_string_literal: true

class User::BulkDestroy
  include Service::Base

  params do
    attribute :user_ids, :array

    validates :user_ids, length: { maximum: 100 }
  end

  model :users
  policy :can_delete_users
  step :delete

  private

  def fetch_users(params:)
    ids = params.user_ids
    # this order cluase ensures we retrieve the users in the same order as the
    # IDs in the param. we do this to ensure the users are deleted in the same
    # order as they're selected in the UI
    User.where(id: ids).order(DB.sql_fragment("array_position(ARRAY[?], users.id)", ids))
  end

  def can_delete_users(guardian:, users:)
    users.all? { |u| guardian.can_delete_user?(u) }
  end

  def delete(users:, guardian:)
    users.find_each.with_index do |user, index|
      position = index + 1
      success =
        UserDestroyer.new(guardian.user).destroy(
          user,
          delete_posts: true,
          prepare_for_destroy: true,
          context: I18n.t("staff_action_logs.bulk_user_delete"),
        )

      if success
        publish_progress(
          guardian.user,
          { position:, username: user.username, total: users.size, success: true },
        )
      else
        publish_progress(
          guardian.user,
          {
            position:,
            username: user.username,
            total: users.size,
            failed: true,
            error: user.errors.full_messages.join(", "),
          },
        )
      end
    rescue => err
      publish_progress(
        guardian.user,
        { position:, username: user.username, total: users.size, failed: true, error: err.message },
      )
    end
  end

  def publish_progress(actor, data)
    ::MessageBus.publish("/bulk-user-delete", data, user_ids: [actor.id])
  end
end
