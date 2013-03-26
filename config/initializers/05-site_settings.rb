RailsMultisite::ConnectionManagement.each_connection do
  begin
    # clean-up the 'requires_restart' application flag
    Discourse.application_started
    SiteSetting.refresh!
  rescue ActiveRecord::StatementInvalid
    # This will happen when migrating a new database
  end
end
