# frozen_string_literal: true

class AccessControlList::ReassignDeletedUserOwnership
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :username, :string
    attribute :deleted_at, :datetime

    validates :user_id, numericality: { only_integer: true }
    validates :username, :deleted_at, presence: true
  end

  policy :is_system_actor

  transaction do
    model :owner_acls, optional: true
    only_if(:owns_acl_targets) do
      model :random_admin
      each(:owner_acls) { step :reassign_ownership }
    end
  end

  private

  def is_system_actor(guardian:)
    return false if guardian.anonymous?
    guardian.user.is_system_user?
  end

  def fetch_owner_acls(params:)
    AccessControlList
      .where(permission: Acl::Permissions::OWNER)
      .allowing_user(params.user_id)
      .order(:target_type, :target_id)
      .to_a
  end

  def owns_acl_targets(owner_acls:)
    owner_acls.any?
  end

  def fetch_random_admin(params:)
    User
      .active_admins
      .not_suspended
      .where.not(id: params.user_id)
      .order(Arel.sql("RANDOM()"))
      .first || Discourse.system_user
  end

  def reassign_ownership(owner_acl:, params:, random_admin:)
    AccessControlList::Action::ReassignDeletedUserOwnership.call(
      owner_acl:,
      new_admin_owner: random_admin,
      deleted_user_id: params.user_id,
      deleted_username: params.username,
      deleted_at: params.deleted_at,
    )
  end
end
