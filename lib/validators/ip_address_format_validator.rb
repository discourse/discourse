# frozen_string_literal: true

# Allows unique IP address (10.0.1.20), and IP addresses with a mask (10.0.0.0/8).
# Useful when storing in a Postgresql inet column.
class IpAddressFormatValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    # In Rails 4.0.0, ip_address will be nil if an invalid IP address was assigned.
    # https://github.com/jetthoughts/rails/commit/0aa95a71b04f2893921c58a7c1d9fca60dbdcbc2

    # BUT: in Rails 4.0.1, validators don't get a chance to
    # run before IPAddr::InvalidAddressError is raised.
    # I don't see what broke it in rails 4.0.1...
    # So this validator doesn't actually do anything anymore.
    # But let's keep it in case a future version of rails fixes the problem and allows
    # validators to work on inet and cidr columns.
    if record.ip_address.nil?
      record.errors.add(attribute, :invalid)
    end
  end

end
