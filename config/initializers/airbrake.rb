if Rails.env.production? && File.exists?(Rails.root + '/config/airbrake.rb')
  require 'airbrake'
end
