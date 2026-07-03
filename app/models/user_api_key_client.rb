# frozen_string_literal: true

class UserApiKeyClient < ActiveRecord::Base
  has_many :keys, class_name: "UserApiKey", dependent: :destroy
  has_many :scopes,
           class_name: "UserApiKeyClientScope",
           foreign_key: "user_api_key_client_id",
           dependent: :destroy

  def allowed_scopes
    Set.new(scopes.map(&:name))
  end

  def self.invalid_auth_redirect?(auth_redirect)
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
#  application_name :string           not null
#  auth_redirect    :string
#  public_key       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_id        :string           not null
#
# Indexes
#
#  index_user_api_key_clients_on_client_id  (client_id) UNIQUE
#
