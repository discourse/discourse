# frozen_string_literal: true

class AccessControlList::Action::ReassignDeletedUserOwnership < Service::ActionBase
  option :owner_acl
  option :deleted_user_id
  option :deleted_username
  option :deleted_at
  option :new_admin_owner

  def call
    acls =
      AccessControlList.where(target_type: owner_acl.target_type, target_id: owner_acl.target_id)
    current_owner_acl =
      acls.where(permission: Acl::Permissions::OWNER).allowing_user(deleted_user_id).first
    return if !current_owner_acl

    current_owner_acl.update!(
      allowed_user_ids:
        (current_owner_acl.allowed_user_ids - [deleted_user_id] + [new_admin_owner.id]).uniq,
    )

    ordinary_acls =
      acls.where.not(permission: Acl::Permissions::OWNER).allowing_user(new_admin_owner.id)
    ordinary_acls.update_all(
      [
        "allowed_user_ids = array_remove(allowed_user_ids, ?), updated_at = ?",
        new_admin_owner.id,
        Time.current,
      ],
    )
    acls
      .where.not(permission: Acl::Permissions::OWNER)
      .where("allowed_user_ids = '{}'::bigint[] AND allowed_group_ids = '{}'::bigint[]")
      .delete_all

    StaffActionLogger.new(new_admin_owner).log_assume_access_control_ownership(
      current_owner_acl,
      user_id: deleted_user_id,
      username: deleted_username,
      deleted_at:,
    )
  end
end
