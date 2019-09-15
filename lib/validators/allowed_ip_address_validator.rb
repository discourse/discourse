# frozen_string_literal: true

class AllowedIpAddressValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if record.ip_address
      if ScreenedIpAddress.should_block?(record.ip_address)
        record.errors.add(attribute, I18n.t('user.ip_address.blocked'))
      end
      if record.trust_level == TrustLevel[0] && SpamHandler.should_prevent_registration_from_ip?(record.ip_address)
        record.errors.add(attribute, I18n.t('user.ip_address.max_new_accounts_per_registration_ip'))
      end
    end
  end

end
