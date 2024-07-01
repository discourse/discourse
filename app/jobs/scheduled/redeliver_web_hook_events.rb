# frozen_string_literal: true

require "excon"

module Jobs
  class RedeliverWebHookEvents < ::Jobs::Scheduled
    every 1.minute

    sidekiq_options queue: "low"
    sidekiq_options retry: false

    REDELIVERED = "redelivered"
    LIMIT = 20

    def execute(args)
      @redelivery_events = RedeliveringWebhookEvent.includes(web_hook_event: :web_hook).limit(LIMIT)
      if @redelivery_events
        @redelivery_events.each do |redelivery_event|
          begin
            web_hook_event = redelivery_event.web_hook_event
            web_hook = web_hook_event.web_hook

            emitter = WebHookEmitter.new(web_hook, web_hook_event)
            emitter.emit!(
              headers: MultiJson.load(web_hook_event.headers),
              body: web_hook_event.payload,
            )

            publish_webhook_event(web_hook_event, web_hook)
            RedeliveringWebhookEvent.delete(redelivery_event)
          rescue => e
            Rails.logger.warn("Error redelivering web_hook_event #{web_hook_event.id}", e.inspect)
          end

          sleep 2
        end
      end
    end

    private

    def publish_webhook_event(web_hook_event, web_hook)
      MessageBus.publish(
        "/web_hook_events/#{web_hook.id}",
        {
          type: REDELIVERED,
          web_hook_event: AdminWebHookEventSerializer.new(web_hook_event, root: false).as_json,
        },
      )
    end
  end
end
