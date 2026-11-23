# frozen_string_literal: true

# The master keeps the first token's device ID, not the credentials of either persona.
class AnonymousModeSession < ActiveRecord::Base
  belongs_to :master_user, class_name: "User"
  belongs_to :user_auth_token

  # The caller holds the master and source token locks. Move the pointer before
  # deleting the source so ON DELETE CASCADE runs only when the login ends.
  def self.exchange!(source, successor, master:)
    session = find_by(user_auth_token_id: source.id) || new(id: source.id, master_user: master)
    session.update!(user_auth_token: successor)
    RetiredUserAuthToken.create!(
      id: source.id,
      anonymous_mode_session: session,
      token_hash: source.auth_token,
      previous_token_hash: (source.prev_auth_token if source.prev_auth_token != source.auth_token),
      rotated_at: source.rotated_at,
    )
    source.destroy!
    session
  end
end

# == Schema Information
#
# Table name: anonymous_mode_sessions
#
#  id                 :integer          not null, primary key
#  master_user_id     :integer          not null
#  user_auth_token_id :integer          not null
#
# Indexes
#
#  index_anonymous_mode_sessions_on_master_user_id      (master_user_id)
#  index_anonymous_mode_sessions_on_user_auth_token_id  (user_auth_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_auth_token_id => user_auth_tokens.id) ON DELETE => cascade
#
