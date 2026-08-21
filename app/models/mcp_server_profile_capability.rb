# frozen_string_literal: true

class McpServerProfileCapability < ActiveRecord::Base
  KINDS = %w[tool resource resource_template prompt].freeze

  belongs_to :profile,
             class_name: "McpServerProfile",
             foreign_key: :mcp_server_profile_id,
             inverse_of: :capability_policies

  validates :kind, inclusion: { in: KINDS }
  validates :identifier, presence: true, length: { maximum: 200 }
  validates :identifier, uniqueness: { scope: %i[mcp_server_profile_id kind] }

  scope :exposed, -> { where(enabled: true, emergency_blocked: false) }
end

# == Schema Information
#
# Table name: mcp_server_profile_capabilities
#
#  id                    :bigint           not null, primary key
#  emergency_blocked     :boolean          default(FALSE), not null
#  enabled               :boolean          default(FALSE), not null
#  identifier            :string           not null
#  kind                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  mcp_server_profile_id :bigint           not null
#
# Indexes
#
#  idx_mcp_profile_capabilities_unique  (mcp_server_profile_id,kind,identifier) UNIQUE
#
