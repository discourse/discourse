# frozen_string_literal: true

class SpamHandler

  def self.should_prevent_registration_from_ip?(ip_address)
    return false if SiteSetting.max_new_accounts_per_registration_ip <= 0

    tl2_plus_accounts_with_same_ip = User.where("trust_level >= ?", TrustLevel[2])
      .where(ip_address: ip_address.to_s)
      .count

    return false if tl2_plus_accounts_with_same_ip > 0

    staff_user_ids = Group[:staff].user_ids - [-1]
    staff_members_with_same_ip = User.where(id: staff_user_ids)
      .where(ip_address: ip_address.to_s)
      .count

    return false if staff_members_with_same_ip > 0

    ip_whitelisted = ScreenedIpAddress.is_whitelisted?(ip_address)
    return false if ip_whitelisted

    tl0_accounts_with_same_ip = User.unscoped
      .where(trust_level: TrustLevel[0])
      .where(ip_address: ip_address.to_s)
      .count

    tl0_accounts_with_same_ip >= SiteSetting.max_new_accounts_per_registration_ip
  end

end
