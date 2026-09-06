# frozen_string_literal: true

class EmailLoginCode < ActiveRecord::Base
  class CodeAccessError < StandardError
  end

  CODE_LENGTH = 6
  MAX_ATTEMPTS = 5
  VALID_FOR = 10.minutes

  validates :email, :code_hash, presence: true

  scope :active,
        -> do
          where(consumed_at: nil).where("expires_at > ?", Time.zone.now).where(
            "attempts < ?",
            MAX_ATTEMPTS,
          )
        end
  scope :for_email, ->(email) { where("lower(email) = ?", email.downcase) }

  def self.generate!(email:)
    email = email.downcase

    code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")

    record = nil
    transaction do
      where("lower(email) = ?", email).delete_all
      record = create!(email: email, code_hash: hash_code(code), expires_at: VALID_FOR.from_now)
    end

    record.instance_variable_set(:@code, code)
    record
  end

  def self.hash_code(code)
    # Keyed with the server secret so a database snapshot alone can't be used
    # to enumerate the small (6-digit) code space offline.
    OpenSSL::HMAC.hexdigest("SHA256", GlobalSetting.safe_secret_key_base, code)
  end

  def code
    raise CodeAccessError.new if @code.blank?

    @code
  end

  # Verifies a submitted code against this record. Burns one attempt up front
  # (atomically, so parallel guesses cannot exceed MAX_ATTEMPTS) and refunds it
  # on success so a pending second factor round-trip can verify again.
  def verify(submitted)
    return false if consumed_at.present? || expires_at <= Time.zone.now

    attempts = DB.query_single(<<~SQL, id: id, max: MAX_ATTEMPTS).first
        UPDATE email_login_codes
        SET attempts = attempts + 1
        WHERE id = :id AND attempts < :max
        RETURNING attempts
      SQL
    return false if attempts.nil?
    self.attempts = attempts

    if ActiveSupport::SecurityUtils.secure_compare(code_hash, self.class.hash_code(submitted))
      update_columns(attempts: 0)
      true
    else
      false
    end
  end

  # Atomically marks the code consumed. Returns true only for the caller that
  # wins the race, so two concurrent redemptions of the same code can't both
  # succeed.
  def consume!
    now = Time.zone.now
    won = self.class.where(id: id, consumed_at: nil).update_all(consumed_at: now) == 1
    self.consumed_at = now if won
    won
  end
end

# == Schema Information
#
# Table name: email_login_codes
#
#  id          :bigint           not null, primary key
#  attempts    :integer          default(0), not null
#  code_hash   :string           not null
#  consumed_at :datetime
#  email       :string           not null
#  expires_at  :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_email_login_codes_on_expires_at   (expires_at)
#  index_email_login_codes_on_lower_email  (lower((email)::text))
#
