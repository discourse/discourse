# frozen_string_literal: true

describe DiscourseEvents::McpTools::ListEvents do
  fab!(:user)

  it "returns upcoming events without past events" do
    Fabricate(
      :event,
      name: "Past event",
      original_starts_at: 2.days.ago.iso8601,
      original_ends_at: 1.day.ago.iso8601,
    )
    upcoming_event =
      Fabricate(
        :event,
        name: "Upcoming event",
        original_starts_at: 1.day.from_now.iso8601,
        original_ends_at: 2.days.from_now.iso8601,
      )
    request_context = instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)

    result = described_class.call(arguments: {}, request_context:)

    expect(result.dig(:structuredContent, :events).pluck(:id)).to eq([upcoming_event.id])
  end
end
