# frozen_string_literal: true

unless String === SiteSetting.push_api_secret_key && SiteSetting.push_api_secret_key.length == 32
  SiteSetting.push_api_secret_key = SecureRandom.hex
end
