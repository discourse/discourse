require_dependency 'email_validator'

class UserEmail < ActiveRecord::Base
  belongs_to :user

  before_validation :strip_downcase_email

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: EmailValidator.email_regex }, if: :email_changed?
  validates :email, email: true, if: :email_changed?

  def strip_downcase_email
    if self.email
      self.email = self.email.strip
      self.email = self.email.downcase
    end
  end
end
