# frozen_string_literal: true

class AiMcpOauthToken < ActiveRecord::Base
  belongs_to :ai_mcp_server, inverse_of: :oauth_token

  validates :ai_mcp_server_id, uniqueness: true
  validates :access_token, length: { maximum: 10_000 }, allow_blank: true
  validates :refresh_token, length: { maximum: 10_000 }, allow_blank: true
end

# == Schema Information
#
# Table name: ai_mcp_oauth_tokens
#
#  id               :bigint           not null, primary key
#  access_token     :text
#  refresh_token    :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  ai_mcp_server_id :bigint           not null
#
# Indexes
#
#  index_ai_mcp_oauth_tokens_on_ai_mcp_server_id  (ai_mcp_server_id) UNIQUE
#
