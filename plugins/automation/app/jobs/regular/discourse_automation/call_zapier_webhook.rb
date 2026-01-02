# frozen_string_literal: true

module Jobs
  module DiscourseAutomation
    class CallZapierWebhook < ::Jobs::Base
      def execute(args)
        RateLimiter.new(nil, "discourse_automation_call_zapier", 5, 30).performed!

        result =
          Excon.post(
            args["webhook_url"],
            body: args["context"].to_json,
            headers: {
              "Content-Type" => "application/json",
              "Accept" => "application/json",
            },
          )

        if result.status != 200
          ::DiscourseAutomation::Logger.warn(
            "Failed to call Zapier webhook at #{args["webhook_url"]} Status: #{result.status}: #{result.status_line}",
          )
        end
      end
    end
  end
end
