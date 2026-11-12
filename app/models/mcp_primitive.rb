# frozen_string_literal: true

class McpPrimitive < ActiveRecord::Base
  KINDS = %w[tool resource resource_template prompt].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :identifier, presence: true, length: { maximum: 200 }
  validates :identifier, uniqueness: { scope: :kind }

  scope :exposed, -> { where(enabled: true, emergency_blocked: false) }

  def exposed?
    enabled? && !emergency_blocked?
  end
end

# == Schema Information
#
# Table name: mcp_primitives
#
#  id                  :bigint           not null, primary key
#  consent_required_at :datetime
#  emergency_blocked   :boolean          default(FALSE), not null
#  enabled             :boolean          default(FALSE), not null
#  identifier          :string           not null
#  kind                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  idx_mcp_primitives_unique  (kind,identifier) UNIQUE
#
