# frozen_string_literal: true

class EmailToken < ActiveRecord::Base
  class TokenAccessError < StandardError; end

  belongs_to :user

  validates :user_id, :email, :token_hash, presence: true

  scope :unconfirmed, -> { where(confirmed: false) }
  scope :active, -> { where(expired: false).where('created_at >= ?', SiteSetting.email_token_valid_hours.hours.ago) }

  after_initialize do
    if self.token_hash.blank?
      @token ||= SecureRandom.hex
      self.token = @token
      self.token_hash = self.class.hash_token(@token)
    end
  end

  before_validation do
    self.email = self.email.downcase if self.email
  end

  after_create do
    EmailToken
      .where(user_id: self.user_id)
      .where.not(id: self.id)
      .update_all(expired: true)
  end

  def token
    raise TokenAccessError.new if @token.blank?
    self[:token]
  end

  def self.confirm(token, skip_reviewable: false)
    User.transaction do
      result = atomic_confirm(token)
      user = result[:user]

      if result[:success]
        user.send_welcome_message = !user.active?
        user.email = result[:email_token].email
        user.active = true
        user.custom_fields.delete('activation_reminder')
        user.save!
        user.create_reviewable if !skip_reviewable
        user.set_automatic_groups
        DiscourseEvent.trigger(:user_confirmed_email, user)
      end

      if user
        Invite.redeem_from_email(user.email)
        user.reload
      end
    end
  rescue ActiveRecord::RecordInvalid
    # If the user's email is already taken, just return nil (failure)
  end

  def self.atomic_confirm(token)
    email_token = confirmable(token)
    return { success: false } if email_token.blank?

    row_count = active
      .where(id: email_token.id)
      .update_all(confirmed: true)

    if row_count == 1
      { success: true, user: email_token.user, email_token: email_token }
    else
      { success: false, user: email_token.user }
    end
  end

  def self.confirmable(token)
    return nil if token.blank?

    unconfirmed.active.includes(:user).where(token_hash: hash_token(token)).first
  end

  def self.hash_token(token)
    Digest::SHA256.hexdigest(token)
  end
end

# == Schema Information
#
# Table name: email_tokens
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  email      :string           not null
#  token      :string           not null
#  confirmed  :boolean          default(FALSE), not null
#  expired    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  token_hash :string           not null
#
# Indexes
#
#  index_email_tokens_on_token    (token) UNIQUE
#  index_email_tokens_on_user_id  (user_id)
#
