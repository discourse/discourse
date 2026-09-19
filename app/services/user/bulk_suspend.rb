# frozen_string_literal: true

class User::BulkSuspend
  include Service::Base

  params do
    attribute :user_ids, :array, compact_blank: true
    attribute :reason, :string
    attribute :suspend_until, :datetime
    attribute :message, :string

    validates :user_ids, length: { minimum: 1, maximum: 100 }
    validates :reason, presence: true, length: { maximum: 300 }
    validates :suspend_until, presence: true
  end

  model :users
  policy :can_suspend_users
  step :suspend

  private

  def fetch_users(params:)
    # this order clause ensures we retrieve the users in the same order as the
    # IDs in the param. we do this to ensure the users are suspended in the same
    # order as they're selected in the UI
    User
      .where(id: params.user_ids)
      .order(DB.sql_fragment("array_position(ARRAY[?], users.id)", params.user_ids))
      .to_a
  end

  def can_suspend_users(guardian:, users:)
    users.all? { guardian.can_suspend?(it) && !it.suspended? }
  end

  def suspend(users:, guardian:, params:)
    users
      .each
      .with_index(1) do |user, position|
        User::Action::SuspendAndPublish.call(
          user:,
          position:,
          guardian:,
          total_size: users.size,
          suspend_until: params.suspend_until,
          reason: params.reason,
          message: params.message,
        )
      end
  end
end
