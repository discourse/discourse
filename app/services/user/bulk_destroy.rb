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
    User.where(id: params.user_ids.to_a)
  end

  def can_delete_users(guardian:, users:)
    users.all? { |u| guardian.can_delete_user?(u) }
  end

  def delete(users:, guardian:)
    users.each do |u|
      UserDestroyer.new(guardian.user).destroy(
        u,
        delete_posts: true,
        context: I18n.t("staff_action_logs.bulk_user_delete", users: users.map(&:id).inspect),
      )
    end
  end
end
