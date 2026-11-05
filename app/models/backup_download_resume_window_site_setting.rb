# frozen_string_literal: true

class BackupDownloadResumeWindowSiteSetting < EnumSiteSetting
  DISABLED = "disabled"
  ONE_HOUR = "1_hour"
  SIX_HOURS = "6_hours"
  TWELVE_HOURS = "12_hours"
  UNTIL_EMAIL_TOKEN_EXPIRES = "until_email_token_expires"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.backups.resume_window.disabled", value: DISABLED },
      { name: "admin.backups.resume_window.one_hour", value: ONE_HOUR },
      { name: "admin.backups.resume_window.six_hours", value: SIX_HOURS },
      { name: "admin.backups.resume_window.twelve_hours", value: TWELVE_HOURS },
      {
        name: "admin.backups.resume_window.until_email_token_expires",
        value: UNTIL_EMAIL_TOKEN_EXPIRES,
      },
    ]
  end

  def self.resume_ttl(value, email_token_ttl:)
    email_token_ttl = email_token_ttl.to_i
    return 0 if email_token_ttl <= 0

    maximum_ttl =
      case value
      when DISABLED
        0
      when ONE_HOUR
        1.hour.to_i
      when SIX_HOURS
        6.hours.to_i
      when TWELVE_HOURS
        12.hours.to_i
      when UNTIL_EMAIL_TOKEN_EXPIRES
        email_token_ttl
      else
        0
      end

    [email_token_ttl, maximum_ttl].min
  end

  def self.translate_names?
    true
  end
end
