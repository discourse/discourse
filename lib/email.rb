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
    parsed.address == email && parsed.local != parsed.address && parsed.domain && parsed.domain.split(".").length > 1
  rescue Mail::Field::ParseError
    false
  end

  def self.downcase(email)
    return email unless Email.is_valid?(email)
    email.downcase
  end

  def self.cleanup_alias(name)
    # TODO: I'm sure there are more, but I can't find a list
    name ? name.gsub(/[:<>,]/, '') : name
  end

end
