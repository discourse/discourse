# frozen_string_literal: true

class McpGroupScope < ActiveRecord::Base
  belongs_to :group

  validates :scope, presence: true, uniqueness: { scope: :group_id }
  validate :scope_is_registered

  def self.ensure_admins!
    admin_group_id = Group::AUTO_GROUPS[:admins]
    return if exists?(group_id: admin_group_id)

    timestamp = Time.zone.now
    insert_all(
      DiscourseMcp.registry.scopes.map do |scope|
        { group_id: admin_group_id, scope:, created_at: timestamp, updated_at: timestamp }
      end,
      unique_by: %i[group_id scope],
    )
  end

  private

  def scope_is_registered
    errors.add(:scope, :inclusion) if !DiscourseMcp.registry.scopes.include?(scope)
  end
end

# == Schema Information
#
# Table name: mcp_group_scopes
#
#  id         :bigint           not null, primary key
#  scope      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :integer          not null
#
# Indexes
#
#  index_mcp_group_scopes_on_group_id_and_scope  (group_id,scope) UNIQUE
#
