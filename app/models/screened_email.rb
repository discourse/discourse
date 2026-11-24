# frozen_string_literal: true

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

  def self.canonical(email)
    name, domain = email.split("@", 2)
    name = name.gsub(/\+.*/, "")
    name = name.gsub(".", "") if %w[gmail.com googlemail.com].include?(domain.downcase)
    "#{name}@#{domain}".downcase
  end

  def self.block(email, opts = {})
    email = canonical(email)
    find_by_email(email) || create!(opts.slice(:action_type, :ip_address).merge(email: email))
  end

  def self.should_block?(email)
    email = canonical(email)

    screened_emails = ScreenedEmail.order(created_at: :desc).limit(100)

    distances = {}
    screened_emails.each do |se|
      distances[se.email] = levenshtein(se.email.downcase, email.downcase)
    end

    max_distance = SiteSetting.levenshtein_distance_spammer_emails
    screened_email =
      screened_emails
        .select { |se| distances[se.email] <= max_distance }
        .sort { |se| distances[se.email] }
        .first

    screened_email.record_match! if screened_email

    screened_email.try(:action_type) == actions[:block]
  end

  def self.levenshtein(first, second)
    return 0 if first == second

    if first.ascii_only? && second.ascii_only?
      ascii_levenshtein(first, second)
    else
      codepoint_levenshtein(first.chars, second.chars)
    end
  end

  def self.ascii_levenshtein(first, second)
    len1 = first.bytesize
    len2 = second.bytesize

    prefix = 0
    min_len = len1 < len2 ? len1 : len2
    prefix += 1 while prefix < min_len && first.getbyte(prefix) == second.getbyte(prefix)

    suffix = 0
    rem_min = min_len - prefix
    while suffix < rem_min && first.getbyte(len1 - 1 - suffix) == second.getbyte(len2 - 1 - suffix)
      suffix += 1
    end

    m = len1 - prefix - suffix
    n = len2 - prefix - suffix
    return n if m == 0
    return m if n == 0

    if m > n
      first, second = second, first
      m, n = n, m
    end

    row = Array.new(m + 1) { |k| k }
    i = 0
    while i < n
      c2 = second.getbyte(prefix + i)
      prev_diag = row[0]
      row[0] = i + 1
      j = 0
      while j < m
        old_up = row[j + 1]
        if first.getbyte(prefix + j) == c2
          row[j + 1] = prev_diag
        else
          left = row[j]
          best = old_up < left ? old_up : left
          best = prev_diag if prev_diag < best
          row[j + 1] = best + 1
        end
        prev_diag = old_up
        j += 1
      end
      i += 1
    end

    row[m]
  end
  private_class_method :ascii_levenshtein

  def self.codepoint_levenshtein(cp1, cp2)
    len1 = cp1.length
    len2 = cp2.length

    prefix = 0
    min_len = len1 < len2 ? len1 : len2
    prefix += 1 while prefix < min_len && cp1[prefix] == cp2[prefix]

    suffix = 0
    rem_min = min_len - prefix
    suffix += 1 while suffix < rem_min && cp1[len1 - 1 - suffix] == cp2[len2 - 1 - suffix]

    m = len1 - prefix - suffix
    n = len2 - prefix - suffix
    return n if m == 0
    return m if n == 0

    if m > n
      cp1, cp2 = cp2, cp1
      m, n = n, m
    end

    row = Array.new(m + 1) { |k| k }
    i = 0
    while i < n
      c2 = cp2[prefix + i]
      prev_diag = row[0]
      row[0] = i + 1
      j = 0
      while j < m
        old_up = row[j + 1]
        if cp1[prefix + j] == c2
          row[j + 1] = prev_diag
        else
          left = row[j]
          best = old_up < left ? old_up : left
          best = prev_diag if prev_diag < best
          row[j + 1] = best + 1
        end
        prev_diag = old_up
        j += 1
      end
      i += 1
    end

    row[m]
  end
  private_class_method :codepoint_levenshtein
end

# == Schema Information
#
# Table name: screened_emails
#
#  id            :integer          not null, primary key
#  action_type   :integer          not null
#  email         :string           not null
#  ip_address    :inet
#  last_match_at :datetime
#  match_count   :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_screened_emails_on_email          (email) UNIQUE
#  index_screened_emails_on_last_match_at  (last_match_at)
#
