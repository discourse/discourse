# frozen_string_literal: true

# Read only for revocation, never to authenticate a user or issue a credential.
class RetiredUserAuthToken < ActiveRecord::Base
  belongs_to :anonymous_mode_session
  has_one :master_user, through: :anonymous_mode_session
  has_one :user_auth_token, through: :anonymous_mode_session

  scope :unexpired, -> { where("rotated_at > ?", SiteSetting.maximum_session_age.hours.ago) }

  def self.revoke_by_cookie(raw_token)
    token_hash = UserAuthToken.hash_token(raw_token)
    retired =
      unexpired.find_by("token_hash = :hash OR previous_token_hash = :hash", hash: token_hash)
    retired&.master_user&.with_credential_lock do
      # Another exchange, expiry or logout may have committed while we waited.
      unexpired.find_by(id: retired.id)&.user_auth_token&.destroy!
    end
  end
end

# == Schema Information
#
# Table name: retired_user_auth_tokens
#
#  id                        :integer          not null, primary key
#  previous_token_hash       :string
#  rotated_at                :datetime         not null
#  token_hash                :string           not null
#  anonymous_mode_session_id :integer          not null
#
# Indexes
#
#  index_retired_user_auth_tokens_on_anonymous_mode_session_id  (anonymous_mode_session_id)
#  index_retired_user_auth_tokens_on_previous_token_hash        (previous_token_hash) UNIQUE WHERE (previous_token_hash IS NOT NULL)
#  index_retired_user_auth_tokens_on_rotated_at                 (rotated_at)
#  index_retired_user_auth_tokens_on_token_hash                 (token_hash) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (anonymous_mode_session_id => anonymous_mode_sessions.id) ON DELETE => cascade
#
