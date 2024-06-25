# frozen_string_literal: true

require "excon"

module Jobs
  class RedeliverWebHookEvent < ::Jobs::Base
    sidekiq_options queue: "low"
    sidekiq_options retry: false

    REDELIVERED = "redelivered"

    def execute(args)
      @arguments = args
      @web_hook = WebHook.find_by(id: @arguments[:web_hook_id])
      @web_hook_event = WebHookEvent.find_by(id: @arguments[:web_hook_event_id])

      redeliver_webhook!
    end

    private

    def redeliver_webhook!
      emitter = WebHookEmitter.new(@web_hook, @web_hook_event)
      emitter.emit!(headers: MultiJson.load(@web_hook_event.headers), body: @web_hook_event.payload)

      publish_webhook_event(@web_hook_event)
    end

    def publish_webhook_event(web_hook_event)
      MessageBus.publish(
        "/web_hook_events/#{@web_hook.id}",
        {
          type: REDELIVERED,
          web_hook_event: AdminWebHookEventSerializer.new(web_hook_event, root: false).as_json,
        },
      )
    end
  end
end
