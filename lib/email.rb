# frozen_string_literal: true

require "mail"

module Email
  # See https://www.iana.org/assignments/smtp-enhanced-status-codes/smtp-enhanced-status-codes.xhtml#smtp-enhanced-status-codes-1
  SMTP_STATUS_SUCCESS = "2."
  SMTP_STATUS_TRANSIENT_FAILURE = "4."
  SMTP_STATUS_PERMANENT_FAILURE = "5."

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
