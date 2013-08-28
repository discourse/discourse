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

# == Schema Information
#
# Table name: screened_emails
#
#  id            :integer          not null, primary key
#  email         :string(255)      not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address    :string
#
# Indexes
#
#  index_blocked_emails_on_email          (email) UNIQUE
#  index_blocked_emails_on_last_match_at  (last_match_at)
#

