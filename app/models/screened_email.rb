require_dependency 'screening_model'

# A ScreenedEmail record represents an email address that is being watched,
# typically when creating a new User account. If the email of the signup form
# (or some other form) matches a ScreenedEmail record, an action can be
# performed based on the action_type.
class ScreenedEmail < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :email, presence: true, uniqueness: true

  before_save :downcase_email

  def downcase_email
    self.email = email.downcase
  end

  def self.block(email, opts = {})
    find_by_email(Email.downcase(email)) || create(opts.slice(:action_type, :ip_address).merge(email: email))
  end

  def self.should_block?(email)
    screened_emails = ScreenedEmail.order(created_at: :desc).limit(100)

    distances = {}
    screened_emails.each { |se| distances[se.email] = levenshtein(se.email.downcase, email.downcase) }

    max_distance = SiteSetting.levenshtein_distance_spammer_emails
    screened_email = screened_emails.select { |se| distances[se.email] <= max_distance }
      .sort   { |se| distances[se.email] }
      .first

    screened_email.record_match! if screened_email

    screened_email.try(:action_type) == actions[:block]
  end

  def self.levenshtein(first, second)
    matrix = [(0..first.length).to_a]
    (1..second.length).each do |j|
      matrix << [j] + [0] * (first.length)
    end

    (1..second.length).each do |i|
      (1..first.length).each do |j|
        if first[j - 1] == second[i - 1]
          matrix[i][j] = matrix[i - 1][j - 1]
        else
          matrix[i][j] = [
            matrix[i - 1][j],
            matrix[i][j - 1],
            matrix[i - 1][j - 1],
          ].min + 1
        end
      end
    end
    matrix.last.last
  end

end

# == Schema Information
#
# Table name: screened_emails
#
#  id            :integer          not null, primary key
#  email         :string           not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address    :inet
#
# Indexes
#
#  index_screened_emails_on_email          (email) UNIQUE
#  index_screened_emails_on_last_match_at  (last_match_at)
#
