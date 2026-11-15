# frozen_string_literal: true

class AccessControlList::Action::BuildReplacement < Service::ActionBase
  Result =
    Data.define(
      :flattened_acl,
      :permissions,
      :added_owner_user_ids,
      :removed_owner_user_ids,
      :ordinary_permissions_changed,
    )

  option :acl_entries
  option :initial_owner
  option :owner_user_ids
  option :target
  option :current_acl

  def call
    current_owner_user_ids = current_acl.permission_user_ids(Acl::Permissions::OWNER)
    desired_owner_user_ids = owner_user_ids || current_owner_user_ids
    if current_owner_user_ids.empty?
      desired_owner_user_ids = desired_owner_user_ids + [initial_owner.id]
    end
    desired_owner_user_ids = desired_owner_user_ids.uniq

    owner_acl =
      desired_owner_user_ids.map do |user_id|
        { type: :user, id: user_id, permission: Acl::Permissions::OWNER }
      end
    editable_acl =
      acl_entries.reject { |acl| acl[:type] == :user && desired_owner_user_ids.include?(acl[:id]) }
    flattened_acl = AccessControlList.inject_mandatory_acl(editable_acl + owner_acl, target)
    permissions = Acl::Target.new(flattened_acl).permission_lookup

    Result.new(
      flattened_acl:,
      permissions:,
      added_owner_user_ids: desired_owner_user_ids - current_owner_user_ids,
      removed_owner_user_ids: current_owner_user_ids - desired_owner_user_ids,
      ordinary_permissions_changed:
        current_acl.permission_lookup.except(Acl::Permissions::OWNER) !=
          permissions.except(Acl::Permissions::OWNER),
    )
  end
end
