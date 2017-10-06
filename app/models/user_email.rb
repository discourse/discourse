require_dependency 'email_validator'

class UserEmail < ActiveRecord::Base
  belongs_to :user

  attr_accessor :should_validate_email

  before_validation :strip_downcase_email

  validates :email, presence: true, uniqueness: true

  validates :email, email: true, format: { with: EmailValidator.email_regex },
                    if: :validate_email?

  validates :primary, uniqueness: { scope: [:user_id] }

  private

  def strip_downcase_email
    if self.email
      self.email = self.email.strip
      self.email = self.email.downcase
    end
  end

  def validate_email?
    return false unless self.should_validate_email
    email_changed?
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
