# frozen_string_literal: true

module DiscoursePostEvent
  # Creates, updates or removes a post's event to match the `[event]` block in its raw.
  class Event::SyncFromPost
    include Service::Base

    params do
      attribute :post_id, :integer

      validates :post_id, presence: true
    end

    model :post
    model :raw_event, :parse_event, optional: true

    only_if :event_removed do
      step :remove_event
    end

    only_if :event_present do
      model :event, :upsert_event
      step :schedule_topic_bump
    end

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def parse_event(post:)
      EventParser.extract_events(post).first
    end

    def event_removed(raw_event:, post:)
      return if raw_event.present?
      post.event.present?
    end

    def event_present(raw_event:)
      raw_event.present?
    end

    def remove_event(post:)
      post.event.destroy!
    end

    def upsert_event(post:, raw_event:)
      event = post.event || Event.new(id: post.id)
      attributes = Event::Action::AttributesFromRaw.call(raw_event:, current_status: event.status)
      attributes[:image_upload_id] = Event::Action::ResolveImageUpload.call(
        image: raw_event[:image],
        post:,
      )&.id
      event.update_with_params!(attributes)
      event
    end

    def schedule_topic_bump(event:)
      event.set_topic_bump
    end
  end
end
