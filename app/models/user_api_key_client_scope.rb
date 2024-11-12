# frozen_string_literal: true

class UserApiKeyClientScope < ActiveRecord::Base
  belongs_to :client, class_name: "UserApiKeyClient", foreign_key: "user_api_key_client_id"

  validates :name,
            inclusion: {
              in: UserApiKeyScope.all_scopes.keys.map(&:to_s),
              message: "%{value} is not a valid scope",
            }

  def self.allowed
    Set.new(SiteSetting.allow_user_api_key_client_scopes.split("|"))
  end
end

# == Schema Information
#
# Table name: user_api_key_scopes
#
#  id                 :bigint           not null, primary key
#  user_api_key_client_id    :integer          not null
#  name               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  allowed_parameters :jsonb
#
# Indexes
#
#  index_user_api_key_scopes_on_user_api_key_id  (user_api_key_id)
#
