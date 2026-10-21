# frozen_string_literal: true

class AccessControlListManager
  include Service::Base

  params do
    attribute :target
    attribute :flattened_acl, :array
    attribute :owner, :string
    attribute :owner_user_id, :integer

    validates :target, presence: true
    validates :owner, presence: true, length: { maximum: 100 }
    validates :owner_user_id, presence: true
  end

  # NOTE (martin): Maybe we need some way of defining a policy here to see
  # if the guardian has the permission to change ACLs for the target?
  # For now, we assume that the caller of this service has already done the
  # necessary guardian checks (e.g. can_manage_board? for a kanban board)

  model :owner_user
  model :previous_permissions, optional: true
  model :existing_owner_acl, optional: true
  policy :has_valid_owner_entries
  model :flattened_acl_with_mandatory, optional: true
  policy :has_at_least_one_owner
  policy :has_valid_permissions
  policy :has_no_banned_acl
  policy :has_at_least_one_acl

  transaction do
    step :destroy_acls
    step :insert_acls
    step :log_permission_changes
  end

  step :reload_target

  private

  def fetch_owner_user(params:)
    User.find_by(id: params.owner_user_id)
  end

  def fetch_previous_permissions(params:)
    AccessControlList.where(target: params.target)
  end

  def fetch_existing_owner_acl(previous_permissions:, params:)
    previous_permissions
      .flattened_list(for_target: params.target)
      .select { |acl| acl[:permission] == Acl::Permissions::OWNER }
  end

  def has_valid_owner_entries(params:, existing_owner_acl:, owner_user:)
    submitted_owner_acl =
      params.flattened_acl.select { |acl| acl[:permission].to_s == Acl::Permissions::OWNER }
    authoritative_owner_ids = existing_owner_acl.map { |acl| acl[:id] }
    authoritative_owner_ids << owner_user.id if authoritative_owner_ids.empty?

    submitted_owner_acl.all? do |acl|
      acl[:type].to_sym == :user && authoritative_owner_ids.include?(acl[:id])
    end
  end

  def destroy_acls(previous_permissions:, params:)
    @context[:previous_permissions] = previous_permissions.target_acl(
      params.target,
    ).permission_lookup
    previous_permissions.destroy_all
  end

  def fetch_flattened_acl_with_mandatory(params:, existing_owner_acl:, owner_user:)
    owner_acl = existing_owner_acl
    if owner_acl.empty?
      owner_acl = [AccessControlList.flat_acl_for(owner_user, Acl::Permissions::OWNER)]
    end

    owner_ids = owner_acl.map { |acl| acl[:id] }
    editable_acl =
      params.flattened_acl.reject do |acl|
        acl[:permission].to_s == Acl::Permissions::OWNER ||
          (acl[:type].to_sym == :user && owner_ids.include?(acl[:id]))
      end

    AccessControlList.inject_mandatory_acl(editable_acl + owner_acl, params.target)
  end

  def has_at_least_one_owner(flattened_acl_with_mandatory:)
    flattened_acl_with_mandatory.any? do |acl|
      acl[:type].to_sym == :user && acl[:permission].to_s == Acl::Permissions::OWNER
    end
  end

  def has_valid_permissions(params:, flattened_acl_with_mandatory:)
    valid_permissions = params.target.class.const_get(:ACL_PERMISSIONS).values
    flattened_acl_with_mandatory.all? { |acl| valid_permissions.include?(acl[:permission].to_s) }
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
