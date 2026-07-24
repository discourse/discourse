# frozen_string_literal: true

if RailsMultisite::ConnectionManagement.current_db != RailsMultisite::ConnectionManagement::DEFAULT
  return
end

if User.limit(20).count < 20 && User.where(admin: true).human_users.count == 0
  notice =
    if GlobalSetting.developer_emails.blank?
      "Congratulations, you installed Discourse! Unfortunately, no administrator emails were defined during setup, so finalizing the configuration <a href='https://meta.discourse.org/t/create-admin-account-from-console/17274'>may be difficult</a>."
    else
      emails = GlobalSetting.developer_emails.split(",")
      emails =
        if emails.length > 1
          emails[0..-2].join(", ") << " or #{emails[-1]} "
        else
          emails[0]
        end
      "Congratulations, you installed Discourse! Register a new admin account with #{emails} to finalize configuration."
    end

  if notice != SiteSetting.global_notice
    SiteSetting.global_notice = notice
    SiteSetting.has_login_hint = true
  end
end
