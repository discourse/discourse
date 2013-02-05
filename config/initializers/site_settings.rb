

RailsMultisite::ConnectionManagement.each_connection do 
  SiteSetting.refresh!
end
