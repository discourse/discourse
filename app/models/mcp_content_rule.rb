# frozen_string_literal: true

# One row per active MCP content rule kind. A missing row means the rule kind is
# inactive. DiscourseMcp::ContentPolicy reads these rows on every MCP request.
class McpContentRule < ActiveRecord::Base
  belongs_to :updated_by, class_name: "User", optional: true

  validates :rule_kind, presence: true, uniqueness: true, length: { maximum: 200 }
end

# == Schema Information
#
# Table name: mcp_content_rules
#
#  id            :bigint           not null, primary key
#  config        :jsonb            not null
#  rule_kind     :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  updated_by_id :integer
#
# Indexes
#
#  index_mcp_content_rules_on_rule_kind  (rule_kind) UNIQUE
#
