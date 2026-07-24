# frozen_string_literal: true

module Jobs
  class ConfirmSnsSubscription < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless raw = args[:raw].presence
      return unless json = args[:json].presence
      return unless subscribe_url = json["SubscribeURL"].presence

      return if !Email::Sns.allowed_topic_arn?(json["TopicArn"])
      return unless Email::Sns.authentic?(raw)

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
