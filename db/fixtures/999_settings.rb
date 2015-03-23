if SiteSetting.notification_email == SiteSetting.defaults[:notification_email]
  # don't crash for invalid hostname, which is possible in dev
  SiteSetting.notification_email = "noreply@#{Discourse.current_hostname}" rescue nil
end
