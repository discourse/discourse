# frozen_string_literal: true

class AccessControlList < ActiveRecord::Base
  attr_accessor :allowed_groups_preloaded, :allowed_users_preloaded

  # NOTE: permission column is freeform, but some common
  # types are:
  #
  # - read
  # - write
  # - manage
  # - owner
  #
  # For categories for example we may have:
  #
  # - read
  # - create_posts
  # - create_topics
  #
  # Generally the creator of whatever the linked target
  # record will become an owner by default.

  belongs_to :target, polymorphic: true

  def allowed_users
    @allowed_users ||= User.where(id: allowed_user_ids).to_a
  end

  def allowed_groups
    @allowed_groups ||= Group.where(id: allowed_group_ids).to_a
  end

  scope :with_permission, ->(permission) { where(permission:) }
  scope :for_target_type, ->(target_type) { where(target_type:) }
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

  scope :matching_user,
        ->(user) do
          allowing_any_user([user.id]).or(allowing_any_group(user.belonging_to_group_ids))
        end

  scope :matching_group,
        ->(group) { allowing_any_group([group.id]).or(allowing_users_in_group(group.id)) }

  def self.expand_list(list, target, owner)
    permissions_expanded =
      list.each_with_object({}) do |entry, permissions|
        permissions[entry[:permission]] ||= {}
        permissions[entry[:permission]][:allowed_user_ids] ||= []
        permissions[entry[:permission]][:allowed_group_ids] ||= []

        if entry[:type].to_sym == :group
          permissions[entry[:permission]][:allowed_group_ids] << entry[:id]
        else
          permissions[entry[:permission]][:allowed_user_ids] << entry[:id]
        end
      end

    permissions_expanded.map do |permission_name, permission|
      {
        permission: permission_name,
        allowed_group_ids: permission[:allowed_group_ids],
        allowed_user_ids: permission[:allowed_user_ids],
        target_type: target.class.polymorphic_name,
        target_id: target.id,
        owner: owner,
      }
    end
  end

  module RelationMethods
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

    def flattened_list
      preload_allowed

      flattened_list = []
      each do |access_control_list|
        access_control_list.allowed_group_ids.each do |group_id|
          allowed_group = access_control_list.allowed_groups.find { |ag| ag.id == group_id }
          flattened_list << {
            type: :group,
            id: group_id,
            permission: access_control_list.permission,
            name: allowed_group.name,
            full_name: allowed_group.full_name,
            metadata: {
              auto_group: allowed_group.automatic?,
            },
          }
        end

        # TODO (martin) Properly handle users in a followup PR when we allow adding
        # them in the UI.
      end
      flattened_list
    end
  end

  def self.relation
    super.extending(RelationMethods)
  end

  validates :target_id, uniqueness: { scope: :target_type }
end

# == Schema Information
#
# Table name: access_control_lists
#
#  id                :bigint           not null, primary key
#  allowed_group_ids :bigint           default([]), not null, is an Array
#  allowed_user_ids  :bigint           default([]), not null, is an Array
#  owner             :string           not null
#  permission        :string           not null
#  target_type       :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  target_id         :bigint           not null
#
# Indexes
#
#  idx_access_control_lists_allowed_group_ids               (allowed_group_ids) USING gin
#  idx_access_control_lists_allowed_user_ids                (allowed_user_ids) USING gin
#  index_access_control_lists_on_target_type_and_target_id  (target_type,target_id) UNIQUE
#
