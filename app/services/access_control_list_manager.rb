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

    @context[:new_permissions] = Acl::Target.new(params.flattened_acls).permission_lookup

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
