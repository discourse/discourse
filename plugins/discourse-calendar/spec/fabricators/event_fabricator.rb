# frozen_string_literal: true

Fabricator(:event, from: "DiscoursePostEvent::Event") do
  post { |attrs| attrs[:post] || Fabricate(:post) }

  id { |attrs| attrs[:post].id }

  status do |attrs|
    if attrs[:status]
      DiscoursePostEvent::Event.statuses[attrs[:status]]
    else
      DiscoursePostEvent::Event.statuses[:public]
    end
  end
  original_starts_at { |attrs| attrs[:original_starts_at] || 1.day.from_now.iso8601 }
  original_ends_at { |attrs| attrs[:original_ends_at] }
end

Fabricator(:event_date, from: "DiscoursePostEvent::EventDate") do
  event

  starts_at { |attrs| attrs[:starts_at] || 1.day.from_now.iso8601 }
  ends_at { |attrs| attrs[:ends_at] }
end

def create_post_with_event(user, extra_raw = "")
  start = (Time.now - 10.seconds).utc.iso8601(3)

  PostCreator.create!(
    user,
    title: "Sell a boat party ##{SecureRandom.alphanumeric}",
    raw: "[event start=\"#{start}\" #{extra_raw}]\n[/event]",
  ).reload
end
