# frozen_string_literal: true

require "excon"

module Jobs
  class RedeliverWebHookEvents < ::Jobs::Scheduled
    every 1.minute

    sidekiq_options queue: "low"
    sidekiq_options retry: false

    REDELIVERED = "redelivered"
    REDELIVERY_FAILED = "redelivery_failed"
    LIMIT = 20

    def execute(args)
      redelivery_events =
        RedeliveringWebhookEvent
          .where(processing: false)
          .includes(web_hook_event: :web_hook)
          .limit(LIMIT)
      event_ids = redelivery_events.pluck(:id)
      redelivery_events.update_all(processing: true)
      updated_redelivery_events = RedeliveringWebhookEvent.where(id: event_ids)

      updated_redelivery_events.each do |redelivery_event|
        begin
          web_hook_event = redelivery_event.web_hook_event
          web_hook = web_hook_event.web_hook

          emitter = WebHookEmitter.new(web_hook, web_hook_event)
          emitter.emit!(
            headers: MultiJson.load(web_hook_event.headers),
            body: web_hook_event.payload,
          )

          publish_webhook_event(web_hook_event, web_hook, REDELIVERED)
          RedeliveringWebhookEvent.delete(redelivery_event)
        rescue => e
          Discourse.warn_exception(
            e,
            message: "Error redelivering web_hook_event #{web_hook_event.id}",
          )
          publish_webhook_event(web_hook_event, web_hook, REDELIVERY_FAILED)
          RedeliveringWebhookEvent.delete(redelivery_event)
        end

        sleep 2
      end
    end

    private

    def publish_webhook_event(web_hook_event, web_hook, type)
      MessageBus.publish(
        "/web_hook_events/#{web_hook.id}",
        {
          type: type,
          web_hook_event: AdminWebHookEventSerializer.new(web_hook_event, root: false).as_json,
        },
      )
    end
  end
end
