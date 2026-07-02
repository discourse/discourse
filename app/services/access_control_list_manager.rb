# frozen_string_literal: true

class AccessControlListManager
  include Service::Base

  params do
    attribute :target
    attribute :flattened_acl, :array
    attribute :owner, :string

    validates :target, presence: true
    validates :owner, presence: true, length: { maximum: 100 }
  end

  # NOTE (martin): Maybe we need some way of defining a policy here to see
  # if the guardian has the permission to change ACLs for the target?
  # For now, we assume that the caller of this service has already done the
  # necessary guardian checks (e.g. can_manage_board? for a kanban board)

  model :previous_permissions, optional: true
  model :flattened_acl_with_mandatory, optional: true
  policy :has_no_banned_acl
  policy :has_at_least_one_acl

  transaction do
    step :destroy_acls
    step :insert_acls
    step :log_permission_changes
  end

  step :reload_target

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

  def fetch_flattened_acl_with_mandatory(params:)
    AccessControlList.inject_mandatory_acl(params.flattened_acl, params.target)
  end

  def has_no_banned_acl(params:, flattened_acl_with_mandatory:)
    return true if !params.target.class.has_banned_acl?
    flattened_acl_with_mandatory.none? { |acl| params.target.class.acl_is_banned?(acl) }
  end

  def has_at_least_one_acl(flattened_acl_with_mandatory:)
    flattened_acl_with_mandatory.any?
  end

  def insert_acls(params:, flattened_acl_with_mandatory:)
    bulk_insert_list =
      AccessControlList.expand_list_for_bulk_insert(
        flattened_acl_with_mandatory,
        params.target,
        params.owner,
      )
    @context[:new_permissions] = Acl::Target.new(flattened_acl_with_mandatory).permission_lookup
    AccessControlList.insert_all!(bulk_insert_list)
  end

  def log_permission_changes(guardian:, previous_permissions:, new_permissions:, params:)
    StaffActionLogger.new(guardian.user).log_access_control_list_permission_change(
      params.target,
      previous_permissions,
      new_permissions,
    )
  end

  def reload_target(params:)
    params.target.reload
  end
end
