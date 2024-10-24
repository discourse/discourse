# frozen_string_literal: true

class UserApiKeyClient < ActiveRecord::Base
  has_many :keys, class_name: "UserApiKey", dependent: :destroy

  def self.invalid_auth_redirect?(auth_redirect, client: nil)
    return false if client&.auth_redirect == auth_redirect
    SiteSetting
      .allowed_user_api_auth_redirects
      .split("|")
      .none? { |u| WildcardUrlChecker.check_url(u, auth_redirect) }
  end
end

# == Schema Information
#
# Table name: user_api_key_clients
#
#  id               :bigint           not null, primary key
#  client_id        :string           not null
#  application_name :string           not null
#  public_key       :string
#  auth_redirect    :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_user_api_key_clients_on_client_id  (client_id) UNIQUE
#
