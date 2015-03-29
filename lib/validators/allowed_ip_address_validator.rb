require_dependency "spam_handler"

class AllowedIpAddressValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if record.ip_address
      if ScreenedIpAddress.should_block?(record.ip_address) ||
         (record.trust_level == TrustLevel[0] && SpamHandler.should_prevent_registration_from_ip?(record.ip_address))
        record.errors.add(attribute, options[:message] || I18n.t('user.ip_address.blocked'))
      end
    end
  end

end
