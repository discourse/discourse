# frozen_string_literal: true

module Email
  class Validator
    def self.ensure_valid!(mail)
      Email::Validator.ensure_valid_address_lists!(mail)
      Email::Validator.ensure_valid_date!(mail)

      mail
    end

    def self.ensure_valid_address_lists!(mail)
      %i[to cc bcc].each do |field|
        addresses = mail[field]

        if addresses&.errors.present?
          mail[field] = addresses.to_s.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
        end
      end
    end

    def self.ensure_valid_date!(mail)
      if mail.date.nil?
        raise Email::Receiver::InvalidPost,
              I18n.t("system_messages.email_reject_invalid_post_specified.date_invalid")
      end
    end
  end
end
