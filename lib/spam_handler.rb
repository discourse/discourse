class SpamHandler

  def self.should_prevent_registration_from_ip?(ip_address)
    return false if SiteSetting.max_new_accounts_per_registration_ip <= 0

    tl2_plus_accounts_with_same_ip = User.where("trust_level >= ?", TrustLevel[2])
                                         .where("ip_address = ?", ip_address.to_s)
                                         .count

    return false if tl2_plus_accounts_with_same_ip > 0

    tl0_accounts_with_same_ip = User.unscoped
                                    .where(trust_level: TrustLevel[0])
                                    .where("ip_address = ?", ip_address.to_s)
                                    .count

    tl0_accounts_with_same_ip >= SiteSetting.max_new_accounts_per_registration_ip
  end

end
