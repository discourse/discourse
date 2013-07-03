class EmailToken < ActiveRecord::Base
  belongs_to :user

  validates_presence_of :token
  validates_presence_of :user_id
  validates_presence_of :email

  before_validation(on: :create) do
    self.token = EmailToken.generate_token
  end

  after_create do
    # Expire the previous tokens
    EmailToken.where(['user_id = ? and id != ?', self.user_id, self.id]).update_all 'expired = true'
  end

  def self.token_length
    16
  end

  def self.valid_after
    1.week.ago
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

  def self.confirm(token)
    return unless token.present?
    return unless token.length/2 == EmailToken.token_length

    email_token = EmailToken.where("token = ? and expired = FALSE and created_at >= ?", token, EmailToken.valid_after).includes(:user).first
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
#  index_email_tokens_on_token  (token) UNIQUE
#

