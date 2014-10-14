class EmailToken < ActiveRecord::Base
  belongs_to :user

  validates :token, :user_id, :email, presence: true

  before_validation(on: :create) do
    self.token = EmailToken.generate_token
    self.email = self.email.downcase if self.email
  end

  after_create do
    # Expire the previous tokens
    EmailToken.where(['user_id = ? and id != ?', self.user_id, self.id]).update_all 'expired = true'
  end

  def self.token_length
    16
  end

  def self.valid_after
    SiteSetting.email_token_valid_hours.hours.ago
  end

  def self.confirm_valid_after
    SiteSetting.email_token_grace_period_hours.hours.ago
  end

  def self.unconfirmed
    where(confirmed: false)
  end

  def self.active
    where(expired: false).where('created_at > ?', valid_after)
  end

  def self.generate_token
    SecureRandom.hex(EmailToken.token_length)
  end

  def self.valid_token_format?(token)
    return token.present? && token =~ /[a-f0-9]{#{token.length/2}}/i
  end

  def self.confirm(token)
    return unless valid_token_format?(token)

    email_token = EmailToken.where("token = ? and expired = FALSE AND ((NOT confirmed AND created_at >= ?) OR (confirmed AND created_at >= ?))", token, EmailToken.valid_after, EmailToken.confirm_valid_after).includes(:user).first
    return if email_token.blank?

    user = email_token.user
    User.transaction do
      row_count = EmailToken.where(id: email_token.id, expired: false).update_all 'confirmed = true'
      if row_count == 1
        # If we are activating the user, send the welcome message
        user.send_welcome_message = !user.active?

        user.active = true
        user.email = email_token.email
        user.save!
      end
    end
    # redeem invite, if available
    Invite.redeem_from_email(user.email)
    user
  rescue ActiveRecord::RecordInvalid
    # If the user's email is already taken, just return nil (failure)
  end
end

# == Schema Information
#
# Table name: email_tokens
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  email      :string(255)      not null
#  token      :string(255)      not null
#  confirmed  :boolean          default(FALSE), not null
#  expired    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_email_tokens_on_token    (token) UNIQUE
#  index_email_tokens_on_user_id  (user_id)
#
