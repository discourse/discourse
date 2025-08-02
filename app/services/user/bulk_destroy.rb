# frozen_string_literal: true

class User::BulkDestroy
  include Service::Base

  params do
    attribute :user_ids, :array
    attribute :block_ip_and_email, :boolean, default: false

    validates :user_ids, length: { minimum: 1, maximum: 100 }

    after_validation { user_ids&.compact_blank! }
  end

  model :users
  policy :can_delete_users
  step :delete

  private

  def fetch_users(params:)
    # this order clause ensures we retrieve the users in the same order as the
    # IDs in the param. we do this to ensure the users are deleted in the same
    # order as they're selected in the UI
    User
      .where(id: params.user_ids)
      .order(DB.sql_fragment("array_position(ARRAY[?], users.id)", params.user_ids))
      .to_a
  end

  def can_delete_users(guardian:, users:)
    users.all? { guardian.can_delete_user?(_1) }
  end

  def delete(users:, guardian:, params:)
    users
      .each
      .with_index(1) do |user, position|
        User::Action::DestroyAndPublish.call(
          user:,
          position:,
          guardian:,
          total_size: users.size,
          block_ip_and_email: params.block_ip_and_email,
        )
      end
  end
end
