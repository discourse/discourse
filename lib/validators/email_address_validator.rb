# frozen_string_literal: true

class EmailAddressValidator
  def self.valid_value?(email)
    email.match? email_regex
  end

  def self.email_regex
    /\A[a-zA-Z0-9!#\$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#\$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$\z/
  end
end
