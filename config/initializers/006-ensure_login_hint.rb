# Some sanity checking so we don't count on an unindexed column on boot
if User.limit(20).count < 20 && User.where(admin: true).count == 1
  notice =
    if GlobalSetting.developer_emails.blank?
      "Congratulations, you installed Discourse! Unfortunately, no administrator emails were defined during setup, so finalizing the configuration <a href='https://meta.discourse.org/t/how-to-create-an-administrator-account-after-install/14046'>may be difficult</a>."
    else
      emails = GlobalSetting.developer_emails.split(",")
      if emails.length > 1
        emails = emails[0..-2].join(' , ') << " or #{emails[-1]} "
      else
        emails = emails[0]
      end
      "Congratulations, you installed Discourse! Register a new admin account with #{emails} to finalize configuration."
    end

  if notice != SiteSetting.global_notice
    SiteSetting.global_notice = notice
    SiteSetting.has_login_hint = true
  end

# we may be booting with no User table eg: first migration, just skip
end rescue nil
