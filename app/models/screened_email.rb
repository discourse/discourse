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
    levenshtein_distance = SiteSetting.levenshtein_distance_spammer_emails

    sql = <<-SQL
      JOIN (
        SELECT email, levenshtein_less_equal(email, :email, :levenshtein_distance) AS distance
        FROM screened_emails
        ORDER BY created_at DESC
        LIMIT 100
      ) AS sed ON sed.email = screened_emails.email
    SQL

    screened_emails_distance = ScreenedEmail.sql_fragment(sql, email: email, levenshtein_distance: levenshtein_distance)

    screened_email = ScreenedEmail.joins(screened_emails_distance)
                                  .where("sed.distance <= ?", levenshtein_distance)
                                  .order("sed.distance ASC")
                                  .limit(1)
                                  .first

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
#  created_at    :datetime
#  updated_at    :datetime
#  ip_address    :inet
#
# Indexes
#
#  index_screened_emails_on_email          (email) UNIQUE
#  index_screened_emails_on_last_match_at  (last_match_at)
#
