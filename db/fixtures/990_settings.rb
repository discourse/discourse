if SiteSetting.notification_email == SiteSetting.defaults[:notification_email]
  # don't crash for invalid hostname, which is possible in dev
  begin
    SiteSetting.notification_email = "noreply@#{Discourse.current_hostname}"
  rescue Discourse::InvalidParameters
    STDERR.puts "Discourse hostname: #{Discourse.current_hostname} is not a valid domain for emails!"
  end
end
