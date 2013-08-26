require_dependency 'screening_model'

# A ScreenedEmail record represents an email address that is being watched,
# typically when creating a new User account. If the email of the signup form
# (or some other form) matches a ScreenedEmail record, an action can be
# performed based on the action_type.
class ScreenedEmail < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :email, presence: true, uniqueness: true

  def self.block(email, opts={})
    find_by_email(email) || create(opts.slice(:action_type, :ip_address).merge({email: email}))
  end

  def self.should_block?(email)
    screened_email = ScreenedEmail.where(email: email).first
    screened_email.record_match! if screened_email
    screened_email && screened_email.action_type == actions[:block]
  end

end
