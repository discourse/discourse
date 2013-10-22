# Allows unique IP address (10.0.1.20), and IP addresses with a mask (10.0.0.0/8).
# Useful when storing in a Postgresql inet column.
class IpAddressFormatValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    unless record.ip_address.nil? or record.ip_address.split('/').first =~ Resolv::AddressRegex
      record.errors.add(attribute, :invalid)
    end
  end

end
