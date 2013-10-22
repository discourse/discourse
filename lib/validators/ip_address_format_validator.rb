# Allows unique IP address (10.0.1.20), and IP addresses with a mask (10.0.0.0/8).
# Useful when storing in a Postgresql inet column.
class IpAddressFormatValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if rails4?
      # In Rails 4, ip_address will be nil if an invalid IP address was assigned.
      # https://github.com/jetthoughts/rails/commit/0aa95a71b04f2893921c58a7c1d9fca60dbdcbc2
      if record.ip_address.nil?
        record.errors.add(attribute, :invalid)
      end
    else
      unless !record.ip_address.nil? and record.ip_address.to_s.split('/').first =~ Resolv::AddressRegex
        record.errors.add(attribute, :invalid)
      end
    end
  end

end
