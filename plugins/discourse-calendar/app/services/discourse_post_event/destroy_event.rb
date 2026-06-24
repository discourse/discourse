# frozen_string_literal: true

module DiscoursePostEvent
  class DestroyEvent
    include Service::Base

    params do
      attribute :event_id, :integer

      validates :event_id, presence: true
    end

    model :event
    policy :can_act_on_event

    step :publish_event_update
    model :webhook_payload, :build_webhook_payload
    transaction { step :destroy_event }
    step :enqueue_destroyed_webhooks

    private

    def fetch_event(params:)
      Event.includes(:image_upload).find_by(id: params.event_id)
    end

    def can_act_on_event(guardian:, event:)
      guardian.can_act_on_discourse_post_event?(event)
    end

    def publish_event_update(event:)
      event.publish_update!
    end

    def build_webhook_payload(event:)
      WebHook.build_calendar_event_payload(event)
    end

    def destroy_event(event:)
      event.destroy!
    end

    def enqueue_destroyed_webhooks(event:, webhook_payload:)
      WebHook.enqueue_calendar_event_hooks(:calendar_event_destroyed, event, webhook_payload)
    end
  end
end
