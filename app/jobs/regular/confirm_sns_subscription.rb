# frozen_string_literal: true

module Jobs
  class ConfirmSnsSubscription < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless raw = args[:raw].presence
      return unless json = args[:json].presence
      return unless subscribe_url = json["SubscribeURL"].presence

      require "aws-sdk-sns"
      return unless Aws::SNS::MessageVerifier.new.authentic?(raw)

      uri =
        begin
          URI.parse(subscribe_url)
        rescue URI::Error
          return
        end

      Net::HTTP.get(uri)
    end
  end
end
