# frozen_string_literal: true

class McpAuditLog < ActiveRecord::Base
  belongs_to :user, optional: true
  belongs_to :client,
             class_name: "McpOauthClient",
             foreign_key: :mcp_oauth_client_id,
             optional: true
  validates :occurred_at, :outcome, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }
end

# == Schema Information
#
# Table name: mcp_audit_logs
#
#  id                  :bigint           not null, primary key
#  bucket_at           :datetime
#  duration_ms         :integer
#  http_status         :integer
#  method              :string
#  occurred_at         :datetime         not null
#  occurrences         :integer          default(1), not null
#  outcome             :string           not null
#  target              :jsonb            not null
#  tool                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  mcp_oauth_client_id :bigint
#  request_id          :string
#  user_id             :integer
#
# Indexes
#
#  index_mcp_audit_logs_on_occurred_at_and_id  (occurred_at,id)
#
