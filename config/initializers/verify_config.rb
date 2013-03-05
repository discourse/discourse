# Check that the app is configured correctly. Raise some helpful errors if something is wrong.

if Rails.env.production? && ['localhost', 'production.localhost'].include?(Discourse.current_hostname)
  puts <<END

    Discourse.current_hostname = '#{Discourse.current_hostname}'

    Please update the host_names property in config/database.yml
    so that it uses the hostname of your site. Otherwise you will
    experience problems, like links in emails using #{Discourse.current_hostname}.

END

  raise "Invalid host_names in database.yml"
end