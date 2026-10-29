# frozen_string_literal: true

# Builds the Schema.org script element for an event attached to a topic's first post.
class DiscourseEvents::Events::BuildSchemaMarkup
  include Service::Base

  params do
    attribute :topic_id, :integer
    validates :topic_id, presence: true
  end

  policy :schema_markup_enabled
  model :topic
  policy :can_see_topic
  model :first_post
  model :event
  model :html

  private

  def schema_markup_enabled
    SiteSetting.enable_event_schema_for_topics && SiteSetting.discourse_post_event_enabled
  end

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_see_topic(guardian:, topic:)
    guardian.can_see_topic?(topic)
  end

  def fetch_first_post(topic:)
    topic.posts.includes(event: %i[image_upload event_dates]).find_by(post_number: 1)
  end

  def fetch_event(first_post:)
    event = first_post.event
    event if event&.deleted_at.nil?
  end

  def fetch_html(topic:, first_post:, event:)
    json = DiscourseEvents::Events::Action::GenerateSchemaJson.call(topic:, first_post:, event:)

    "<script type=\"application/ld+json\">#{ERB::Util.json_escape(json)}</script>"
  end
end
