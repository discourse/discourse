# frozen_string_literal: true

class AccessControlList::Apply
  include Service::Base

  params do
    attribute :acl_target_type, :string
    attribute :acl_target_id, :integer
    attribute :acl_entries, :array, default: -> { [] } do
      attribute :type, :symbol
      attribute :id, :integer
      attribute :permission, :string

      validates :type, inclusion: { in: %i[group user] }
      validates :id, numericality: { only_integer: true, greater_than: 0 }
      validates :permission, presence: true
    end
    attribute :source, :string
    attribute :initial_owner_user_id, :integer
    attribute :owner_user_ids, :array

    before_validation do
      if owner_user_ids
        self.owner_user_ids =
          owner_user_ids.map { |user_id| Integer(user_id, exception: false) }.uniq
      end
    end

    validates :acl_target_type, presence: true
    validates :acl_target_id, numericality: { only_integer: true, greater_than: 0 }
    validates :source, presence: true, length: { maximum: 100 }
    validate :owner_user_ids_are_valid

    private

    def owner_user_ids_are_valid
      return if owner_user_ids.nil?

      all_ids_valid =
        owner_user_ids.all? { |user_id| user_id == Discourse::SYSTEM_USER_ID || user_id&.positive? }
      return if all_ids_valid

      errors.add(:owner_user_ids, :invalid)
    end
  end

  model :acl_target
  policy :has_no_owner_entries
  policy :grantees_exist
  policy :requested_owners_exist
  model :current_acl
  model :initial_owner, optional: true
  policy :has_initial_owner
  policy :can_change_owners
  model :replacement
  policy :has_at_least_one_owner
  policy :has_valid_permissions
  policy :has_no_banned_acl

  transaction do
    step :replace_permissions
    only_if(:ordinary_permissions_changed) { step :log_permission_change }
    only_if(:owners_added) { step :log_owner_additions }
    only_if(:owners_removed) { step :log_owner_removals }
  end

  step :refresh_target_permissions

  private

  def fetch_acl_target(params:)
    target_class =
      Site.access_control_target_classes.find { |klass| klass.name == params.acl_target_type }
    target_class&.find_by(id: params.acl_target_id)
  end

  def fetch_current_acl(acl_target:)
    AccessControlList.where(target: acl_target).target_acl(acl_target)
  end

  def fetch_initial_owner(params:, current_acl:)
    if current_acl.permission_user_ids(Acl::Permissions::OWNER).empty?
      User.find_by(id: params.initial_owner_user_id)
    end
  end

  def has_initial_owner(current_acl:, initial_owner:)
    current_acl.permission_user_ids(Acl::Permissions::OWNER).any? || initial_owner.present?
  end

  def has_no_owner_entries(params:)
    params.acl_entries.none? { |entry| entry.permission == Acl::Permissions::OWNER }
  end

  def requested_owners_exist(params:)
    return true if params.owner_user_ids.nil?

    User.where(id: params.owner_user_ids).count == params.owner_user_ids.length
  end

  def grantees_exist(params:)
    group_ids = params.acl_entries.filter_map { |entry| entry.id if entry.type == :group }.uniq
    user_ids = params.acl_entries.filter_map { |entry| entry.id if entry.type == :user }.uniq

    Group.where(id: group_ids).count == group_ids.length &&
      User.where(id: user_ids).count == user_ids.length
  end

  def fetch_replacement(params:, acl_target:, current_acl:, initial_owner:)
    AccessControlList::Action::BuildReplacement.call(
      acl_entries:
        params.acl_entries.map do |entry|
          { type: entry.type, id: entry.id, permission: entry.permission }
        end,
      initial_owner:,
      owner_user_ids: params.owner_user_ids,
      target: acl_target,
      current_acl:,
    )
  end

  def can_change_owners(params:, guardian:, current_acl:)
    return true if params.owner_user_ids.nil?

    guardian.is_admin? ||
      current_acl.permission_user_ids(Acl::Permissions::OWNER).include?(guardian.user&.id)
  end

  def has_at_least_one_owner(replacement:)
    replacement.permissions.dig(Acl::Permissions::OWNER, :user_ids)&.any?
  end

  def has_valid_permissions(acl_target:, replacement:)
    valid_permissions = acl_target.class.const_get(:ACL_PERMISSIONS).values
    replacement.flattened_acl.all? { |entry| valid_permissions.include?(entry[:permission].to_s) }
  end

  def has_no_banned_acl(acl_target:, replacement:)
    return true if !acl_target.class.has_banned_acl?

    replacement.flattened_acl.none? { |entry| acl_target.class.acl_is_banned?(entry) }
  end

  def replace_permissions(params:, acl_target:, replacement:)
    AccessControlList.where(target: acl_target).destroy_all
    AccessControlList.bulk_insert_flattened_acl!(
      replacement.flattened_acl,
      acl_target,
      params.source,
    )
  end

  def ordinary_permissions_changed(replacement:)
    replacement.ordinary_permissions_changed
  end

  def owners_added(replacement:)
    replacement.added_owner_user_ids.any?
  end

  def owners_removed(replacement:)
    replacement.removed_owner_user_ids.any?
  end

  def log_permission_change(guardian:, acl_target:, current_acl:, replacement:)
    StaffActionLogger.new(guardian.user).log_access_control_list_permission_change(
      acl_target,
      current_acl.permission_lookup.except(Acl::Permissions::OWNER),
      replacement.permissions.except(Acl::Permissions::OWNER),
    )
  end

  def log_owner_additions(guardian:, acl_target:, replacement:)
    logger = StaffActionLogger.new(guardian.user)
    User
      .where(id: replacement.added_owner_user_ids)
      .find_each { |user| logger.log_add_access_control_list_owner(acl_target, user) }
  end

  def log_owner_removals(guardian:, acl_target:, replacement:)
    logger = StaffActionLogger.new(guardian.user)
    User
      .where(id: replacement.removed_owner_user_ids)
      .find_each { |user| logger.log_remove_access_control_list_owner(acl_target, user) }
  end

  def refresh_target_permissions(acl_target:)
    acl_target.reload
  end
end
