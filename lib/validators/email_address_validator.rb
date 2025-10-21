# frozen_string_literal: true

class EmailAddressValidator
  EMAIL_REGEX =
    /\A[a-zA-Z0-9!#\$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#\$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$\z/
  ENCODED_WORD_REGEX = /\=\?[^?]+\?[BbQq]\?[^?]+\?\=/

  class << self
    def valid_value?(email)
      # '@' splits the email in two parts local@domain
      # local part must be <= 64 characters
      # domain part must be <= 255 characters
      at_index = email.to_s.index("@")

      !!at_index && at_index <= 64 && (email.length - at_index - 1) <= 255 &&
        email.match?(email_regex) && !email.match?(encoded_word_regex) &&
        decode(email)&.match?(email_regex)
    end

    def email_regex
      EMAIL_REGEX
    end

    def encoded_word_regex
      ENCODED_WORD_REGEX
    end

    private

    def decode(email)
      Mail::Address.new(email).decoded
    rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
      nil
    end
  end
end
