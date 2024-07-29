# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Ensures that the default adapter used for Faraday is our SSRF safe adapter which uses FinalDestination::HTTP
  Faraday.default_adapter = FinalDestination::FaradayAdapter

  # Uncomment when https://github.com/ruby/net-http/commit/fed3dcd0c2b1270a1f0eb9c4a58bed8497989c9a is released. Monkey
  # patch FinalDestination::HTTP for now.
  #
  # Net::HTTP.default_configuration = {
  #   read_timeout: GlobalSetting.http_read_timeout_seconds,
  #   open_timeout: GlobalSetting.http_open_timeout_seconds,
  #   write_timeout: GlobalSetting.http_write_timeout_seconds,
  # }
end
