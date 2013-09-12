require 'airbrake'

Airbrake.configure do |config|
  config.api_key = 'a766118c649bec17b7e49904eb8bf40f'
  config.host    = 'errbit.cphepdev.com'
  config.port    = 80
  config.secure  = config.port == 443
end
