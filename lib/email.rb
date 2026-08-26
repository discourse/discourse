# frozen_string_literal: true

require "mail"

module Email
  # See https://www.iana.org/assignments/smtp-enhanced-status-codes/smtp-enhanced-status-codes.xhtml#smtp-enhanced-status-codes-1
  # both enhanced ("4.X.X") and basic ("4XX") statuses start with the class digit
  def self.smtp_transient_failure?(status)
    status.to_s.start_with?("4")
  end

  # A relay IP, a port, a date and a version string all look like a status, so
  # one is only read where SMTP would put it: leading the diagnostic (after the
  # optional "smtp;" the DSN Diagnostic-Code field carries), or introducing an
  # enhanced status. Anything looser scores bounces off software version numbers.
  SMTP_STATUS_IN_TEXT_REGEXP =
    /
    (?: \A (?:[\w-]+;\s*)? \K [245] (?: \.\d{1,3}\.\d{1,3} | \d\d ) (?![.\d])
      | (?<![.\w]) [245]\d\d (?= [ -]\s? [245]\.\d{1,3}\.\d{1,3} (?![.\d]) )
    )
  /x

  # nil when the text holds no status, so a report that can't be classified is
  # left alone rather than guessed at
  def self.extract_smtp_status(text)
    text.to_s[SMTP_STATUS_IN_TEXT_REGEXP]
  end

  def self.is_valid?(email)
    return false unless String === email
    EmailAddressValidator.valid_value?(email)
  end

  def self.downcase(email)
    return email unless Email.is_valid?(email)
    email.downcase
  end

  def self.obfuscate(email)
    return email if !Email.is_valid?(email)

    first, _, last = email.rpartition("@")

    # Obfuscate each last part, except tld
    last = last.split(".")
    tld = last.pop
    last.map! { |part| obfuscate_part(part) }
    last << tld

    "#{obfuscate_part(first)}@#{last.join(".")}"
  end

  def self.cleanup_alias(name)
    name ? name.gsub(/[:<>,"]/, "") : name
  end

  def self.extract_parts(raw)
    mail = Mail.new(raw)
    text = nil
    html = nil

    if mail.multipart?
      text = mail.text_part
      html = mail.html_part
    elsif mail.content_type.to_s["text/html"]
      html = mail
    else
      text = mail
    end

    [text&.decoded, html&.decoded]
  end

  def self.site_title
    SiteSetting.email_site_title.presence || SiteSetting.title
  end

  private

  def self.obfuscate_part(part)
    if part.size < 3
      "*" * part.size
    elsif part.size < 5
      part[0] + "*" * (part.size - 1)
    else
      part[0] + "*" * (part.size - 2) + part[-1]
    end
  end
end
