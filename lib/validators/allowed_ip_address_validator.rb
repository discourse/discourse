class AllowedIpAddressValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if record.ip_address and ScreenedIpAddress.should_block?(record.ip_address)
      record.errors.add(attribute, options[:message] || I18n.t('user.ip_address.blocked'))
    end
  end

end