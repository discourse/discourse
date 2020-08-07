# frozen_string_literal: true

require 'mail'

module Email
  # cute little guy ain't he?
  MESSAGE_ID_REGEX = /<(.*@.*)+>/

  def self.is_valid?(email)
    return false unless String === email
    !!(EmailValidator.email_regex =~ email)
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

  def self.site_title
    SiteSetting.email_site_title.presence || SiteSetting.title
  end

  # https://tools.ietf.org/html/rfc850#section-2.1.7
  def self.message_id_rfc_format(message_id)
    return message_id if message_id =~ MESSAGE_ID_REGEX
    "<#{message_id}>"
  end

  def self.message_id_clean(message_id)
    return message_id if !(message_id =~ MESSAGE_ID_REGEX)
    message_id.tr("<>", "")
  end
end
