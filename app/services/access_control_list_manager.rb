# frozen_string_literal: true

class AccessControlListManager
  include Service::Base

  params do
    attribute :target
    attribute :flattened_acl, :array
    attribute :owner, :string

    validates :target, presence: true
    validates :flattened_acl, presence: true
    validates :owner, presence: true, length: { maximum: 100 }
  end

  model :previous_permissions, optional: true
  model :flattened_acl_with_mandatory

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

  def fetch_flattened_acl_with_mandatory(params:)
    AccessControlList.inject_mandatory_acl(params.flattened_acl, params.target)
  end

  def insert_acls(params:, flattened_acl_with_mandatory:)
    bulk_insert_list =
      AccessControlList.expand_list(flattened_acl_with_mandatory, params.target, params.owner)
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
end
