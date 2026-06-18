# frozen_string_literal: true

class AccessControlList < ActiveRecord::Base
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

  has_many :allowed_users, class_name: "User", foreign_key: :id, primary_key: :allowed_user_ids
  has_many :allowed_groups, class_name: "Group", foreign_key: :id, primary_key: :allowed_group_ids
  belongs_to :target, polymorphic: true

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

  def self.permissions_matrix(access_control_lists)
    access_control_lists.each_with_object({}) do |access_control_list, hash|
      hash[access_control_list.target_type] ||= {}
      hash[access_control_list.target_type][access_control_list.target_id] ||= []
      # Build a matrix so the output looks like:
      # { "DiscourseKanban::Board" => { 1 => { user_id => ["read", "write"], group_id => ["read"] } } }
      #
      matrix = hash[access_control_list.target_type][access_control_list.target_id]

      # Ensure it's a hash, not an array
      hash[access_control_list.target_type][access_control_list.target_id] = matrix = {
      } unless matrix.is_a?(Hash)

      access_control_list.allowed_user_ids.each do |user_id|
        key = [:user, user_id]
        matrix[key] ||= []
        if matrix[key].exclude?(access_control_list.permission)
          matrix[key] << access_control_list.permission
        end
      end

      access_control_list.allowed_group_ids.each do |group_id|
        key = [:group, group_id]
        matrix[key] ||= []
        if matrix[key].exclude?(access_control_list.permission)
          matrix[key] << access_control_list.permission
        end
      end
    end
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
