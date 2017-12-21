require_dependency 'email_validator'

class UserEmail < ActiveRecord::Base
  belongs_to :user

  attr_accessor :skip_validate_email

  before_validation :strip_downcase_email

  validates :email, presence: true
  validates :email, email: true, format: { with: EmailValidator.email_regex },
                    if: :validate_email?

  validates :primary, uniqueness: { scope: [:user_id] }, if: [:user_id, :primary]
  validate :user_id_not_changed, if: :primary
  validate :unique_email

  private

  def strip_downcase_email
    if self.email
      self.email = self.email.strip
      self.email = self.email.downcase
    end
  end

  def validate_email?
    return false if self.skip_validate_email
    email_changed?
  end

  def unique_email
    if self.will_save_change_to_email? && self.class.where("lower(email) = ?", email).exists?
      self.errors.add(:email, :taken)
    end
  end

  def user_id_not_changed
    if self.will_save_change_to_user_id? && self.persisted?
      self.errors.add(:user_id, I18n.t(
        'active_record.errors.model.user_email.attributes.user_id.reassigning_primary_email')
      )
    end
  end
end

# == Schema Information
#
# Table name: user_emails
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  email      :string(513)      not null
#  primary    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_emails_on_email                (lower((email)::text)) UNIQUE
#  index_user_emails_on_user_id              (user_id)
#  index_user_emails_on_user_id_and_primary  (user_id,primary) UNIQUE
#
