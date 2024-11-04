# frozen_string_literal: true

class EmailAddressValidator
  class << self
    def valid_value?(email)
      email.match?(email_regex) && decode(email)&.match?(email_regex)
    end

    def email_regex
      /\A[a-zA-Z0-9!#\$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#\$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$\z/
    end

    private

    def decode(email)
      Mail::Address.new(email).decoded
    rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
      nil
    end
  end
end
