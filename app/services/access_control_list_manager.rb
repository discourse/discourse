# frozen_string_literal: true

class AccessControlListManager
  include Service::Base

  params do
    attribute :target
    attribute :flattened_acls, :array
    attribute :owner, :string

    validates :target, presence: true
    validates :flattened_acls, presence: true
    validates :owner, presence: true, length: { maximum: 100 }
  end

  model :previous_permissions, optional: true

  transaction do
    step :destroy_acls
    step :insert_acls
    step :log_permission_changes
  end

  private

  def fetch_previous_permissions(params:)
    AccessControlList.where(target: params.target)
  end

  def destroy_acls(previous_permissions:, params:)
    @context[:previous_permissions] = previous_permissions.target_acl(
      params.target,
    ).permission_lookup
    previous_permissions.destroy_all
  end

  def insert_acls(params:)
    bulk_insert_list =
      AccessControlList.expand_list(params.flattened_acls, params.target, params.owner)

    @context[:new_permissions] = AccessControlList::TargetAcl.new(
      params.flattened_acls,
    ).permission_lookup

    AccessControlList.insert_all!(bulk_insert_list)
  end

  def log_permission_changes(previous_permissions:, new_permissions:, params:)
    # StaffActionLog here
  end
end

# AccessControlList.where(target: board).destroy_all
# AccessControlList.insert_all!(
#   AccessControlList.expand_list(
#     context[:raw_board_params]["acl"],
#     board,
#     # TODO (martin) Need to define this in a central place, maybe some
#     # register_acl_owner plugin API? Or easy lookup for Plugin.self.acl_owner?
#     "plugin:discourse-kanban",
#   ),
# )
# TODO (martin) need to configure how best to track these permission/ACL
# changes, probably in core in an AccessControlListManager service...maybe
# BoardHistory#board_permissions_changed will be a callback from the ACL service,
# which will give back the old group ids + user ids + their permissions, then
# the new ones, and we just log this all in the context? Something like:
#
# {
#   previous_permissions: {
#     read: { group_ids: [], user_ids: [] },
#     edit: { group_ids: [], user_ids: [] },
#     manage: { group_ids: [], user_ids: [] },
#   },
#   new_permissions: {
#     read: { group_ids: [], user_ids: [] },
#     edit: { group_ids: [], user_ids: [] },
#     manage: { group_ids: [], user_ids: [] },
#   }
# }
