# frozen_string_literal: true

class AccessControlList < ActiveRecord::Base
  attr_accessor :allowed_groups_preloaded, :allowed_users_preloaded

  # NOTE: permission column is freeform, but some common
  # types are below. In the UI these would generally be
  # displayed as a role (e.g. adding -er), like Viewer,
  # Editor, Manager, Owner, etc:
  #
  # - view
  # - edit
  # - manage
  # - own
  #
  # For categories for example we may have:
  #
  # - view
  # - manage
  # - create_post
  # - create_topic
  #
  # Generally the creator of whatever the linked target
  # record will become an owner by default.

  belongs_to :target, polymorphic: true

  validates :target_id, uniqueness: { scope: %i[target_type permission] }

  before_create { self.owner = "core" if owner.blank? }

  def allowed_users
    @allowed_users ||= User.where(id: allowed_user_ids).to_a
  end

  def allowed_groups
    if @allowed_groups_preloaded.present?
      @allowed_groups ||= @allowed_groups_preloaded
    else
      @allowed_groups ||= Group.where(id: allowed_group_ids).to_a
    end
  end

  def self.relation
    super.extending(AccessControlListRelationMethods)
  end

  scope :allowing_user,
        ->(user_id) { where("allowed_user_ids @> ARRAY[:user_id]::bigint[]", user_id:) }
  scope :allowing_any_user,
        ->(user_ids) { where("allowed_user_ids && ARRAY[:user_ids]::bigint[]", user_ids:) }
  scope :allowing_group,
        ->(group_id) { where("allowed_group_ids @> ARRAY[:group_id]::bigint[]", group_id:) }
  scope :allowing_any_group,
        ->(group_ids) { where("allowed_group_ids && ARRAY[:group_ids]::bigint[]", group_ids:) }
  scope :allowing_users_in_group,
        ->(group_id) do
          where(
            "allowed_user_ids && ARRAY(SELECT user_id FROM group_users WHERE group_id = :group_id)::bigint[]",
            group_id:,
          )
        end
  scope :allowing_anonymous_users, -> { allowing_group(Group::AUTO_GROUPS[:anonymous_users]) }
  scope :with_permission, ->(target, permission) { where(target:, permission:) }

  scope :matching_user,
        ->(user) do
          if user.nil?
            auto_group_ids = [Group::AUTO_GROUPS[:anonymous_users]]

            # TODO (martin) Remove when granular_anonymous_and_logged_in_groups_permissions becomes permanent,
            # it's similar logic to User.in_any_groups?
            if !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
              auto_group_ids << Group::AUTO_GROUPS[:everyone]
            end

            allowing_any_group(auto_group_ids)
          else
            auto_group_ids = [Group::AUTO_GROUPS[:logged_in_users]]

            # TODO (martin) Remove when granular_anonymous_and_logged_in_groups_permissions becomes permanent,
            # it's similar logic to User.in_any_groups?
            if !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
              auto_group_ids << Group::AUTO_GROUPS[:everyone]
            end

            allowing_any_user([user.id]).or(
              allowing_any_group(user.belonging_to_group_ids + auto_group_ids),
            )
          end
        end

  scope :matching_group,
        ->(group) { allowing_any_group([group.id]).or(allowing_users_in_group(group.id)) }

  def self.inject_mandatory_acl(flattened_acl, target)
    return flattened_acl if !target.class.has_mandatory_acl?

    target.class.mandatory_acl.each do |mandatory_acl|
      next if flattened_acl.any? { |acl| AclTarget.acl_matches?(acl, mandatory_acl) }

      flattened_acl << mandatory_acl
    end

    flattened_acl
  end

  # Takes a list in this format, which is the same
  # format from flattened_list that will come from the UI:
  #
  # { type: "group", id: 3, permission: "edit" }]
  #
  # And converts into ACL records that can be inserted into the DB with
  # .insert_all
  def self.expand_list(list, target, owner)
    permissions_expanded =
      list.each_with_object({}) do |entry, permissions|
        permissions[entry[:permission]] ||= {}
        # TODO (martin) Handle allowed_user_ids here too in a followup PR when we allow adding them in the UI.
        permissions[entry[:permission]][:allowed_group_ids] ||= []

        if entry[:type].to_sym == :group
          permissions[entry[:permission]][:allowed_group_ids] << entry[:id]
          # TODO (martin) Handle allowed_user_ids here too in a followup PR when we allow adding them in the UI.
        end
      end

    permissions_expanded.map do |permission_name, permission|
      {
        permission: permission_name,
        # TODO (martin) Handle allowed_user_ids here too in a followup PR when we allow adding them in the UI.
        allowed_group_ids: permission[:allowed_group_ids],
        target_type: target.class.polymorphic_name,
        target_id: target.id,
        owner: owner,
      }
    end
  end

  module AccessControlListRelationMethods
    # Batch-loads the allowed users and groups for every ACL in the relation
    # using two queries total (one per table), then memoizes the records onto
    # each ACL so #allowed_users / #allowed_groups don't trigger N+1s. Returns
    # the (now loaded) relation so it stays chainable.
    def preload_allowed
      acls = to_a

      groups_by_id = Group.where(id: acls.flat_map(&:allowed_group_ids).uniq).index_by(&:id)

      # TODO (martin) Handle users here too in a followup PR
      # users_by_id = User.where(id: acls.flat_map(&:allowed_user_ids).uniq).index_by(&:id)

      acls.each do |acl|
        acl.allowed_groups_preloaded ||= acl.allowed_group_ids.filter_map { |id| groups_by_id[id] }

        # TODO (martin) Handle users here too in a followup PR
      end

      self
    end

    # Used to display a list of user/group -> permission mappings
    # in the UI, and also to construct the TargetAcl and UserAcl
    # objects used for permission checks in Ruby.
    #
    # Takes an ActiveRecord::Relation of AccessControlList records and returns
    # an array of hashes in this format:
    #
    # {
    #  type: :group,
    #  id: 3,
    #  permission: "edit",
    #  name: "Group Name", # only for groups
    #  full_name: "Full Group Name", # only for groups
    #  metadata: {
    #    auto_group: true/false, # only for groups
    #  },
    #  target_id: 123, # only if for_target is not provided
    #  target_type: "Category" # only if for_target is not provided
    # }
    #
    # If for_target is provided, then mixed Relations of
    # AccessControlList records with different targets will NOT
    # be allowed, as this is intended to be used for constructing
    # the TargetAcl for a specific target record e.g. a Category.
    def flattened_list(for_target: nil)
      preload_allowed

      if for_target.present?
        raise Acl::MixedTargetError if map(&:target).uniq.length > 1
      end

      flattened_list = []
      each do |access_control_list|
        target_klass =
          if for_target
            for_target.class
          else
            constantized_target = access_control_list.target_type.safe_constantize

            if constantized_target.nil?
              Rails.logger.warn(
                "[ACL] Unknown target type (#{access_control_list.target_type}) for ACL (#{access_control_list.id}), maybe the plugin is gone or the class has been renamed? Skipping...",
              )
            end

            constantized_target
          end

        next if target_klass.nil?

        access_control_list.allowed_group_ids.each do |group_id|
          allowed_group =
            access_control_list.allowed_groups_preloaded.find { |ag| ag.id == group_id }

          next if allowed_group.nil?

          mandatory =
            target_klass.acl_is_mandatory?(
              { type: :group, id: group_id, permission: access_control_list.permission },
            )

          list_entry = {
            type: :group,
            id: group_id,
            mandatory:,
            permission: access_control_list.permission,
            name: allowed_group.name,
            full_name: allowed_group.full_name,
            metadata: {
              auto_group: allowed_group.automatic?,
            },
          }

          if for_target.present?
            list_entry[:target_id] = for_target.id
            list_entry[:target_type] = target_klass.polymorphic_name
          else
            list_entry[:target_id] = access_control_list.target_id
            list_entry[:target_type] = target_klass.polymorphic_name
          end

          flattened_list << list_entry
        end

        # TODO (martin) Properly handle users in a followup PR when we allow adding
        # them in the UI.
      end

      flattened_list
    end

    # Used to easily access permissions for a single target, e.g. a Category,
    # accessed via the permission_acl method on a Model that has ACLs.
    def target_acl(target)
      ::Acl::Target.new(flattened_list(for_target: target))
    end

    # Used to easily access permissions for a single user,
    # accessed via the permission_acl method on User.
    def user_acl
      ::Acl::User.new(flattened_list)
    end
  end
end

# == Schema Information
#
# Table name: access_control_lists
#
#  id                :bigint           not null, primary key
#  allowed_group_ids :bigint           default([]), not null, is an Array
#  allowed_user_ids  :bigint           default([]), not null, is an Array
#  owner             :string(100)      not null
#  permission        :string(100)      not null
#  target_type       :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  target_id         :bigint           not null
#
# Indexes
#
#  idx_access_control_lists_allowed_group_ids          (allowed_group_ids) USING gin
#  idx_access_control_lists_allowed_user_ids           (allowed_user_ids) USING gin
#  idx_on_target_type_target_id_permission_f472902150  (target_type,target_id,permission) UNIQUE
#
