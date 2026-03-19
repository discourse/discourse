# frozen_string_literal: true

class AiMcpOauthToken < ActiveRecord::Base
  belongs_to :ai_mcp_server, inverse_of: :oauth_token

  validates :ai_mcp_server_id, uniqueness: true
  validates :access_token, length: { maximum: 10_000 }, allow_blank: true
  validates :refresh_token, length: { maximum: 10_000 }, allow_blank: true
end
