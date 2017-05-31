require 'mail'
require_dependency 'email/message_builder'
require_dependency 'email/renderer'
require_dependency 'email/sender'
require_dependency 'email/styles'

module Email

  def self.is_valid?(email)
    return false unless String === email

    parsed = Mail::Address.new(email)

    # Don't allow for a TLD by itself list (sam@localhost)
    # The Grammar is: (local_part "@" domain) / local_part ... need to discard latter
    parsed.address == email &&
    parsed.local != parsed.address &&
    parsed&.domain.split(".").size > 1
  rescue Mail::Field::ParseError
    false
  end

  def self.downcase(email)
    return email unless Email.is_valid?(email)
    email.downcase
  end

  def self.cleanup_alias(name)
    name ? name.gsub(/[:<>,"]/, '') : name
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

end
