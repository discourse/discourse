# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PinTopic::V1 do
  fab!(:topic)
  fab!(:user)

  describe "#execute" do
    it "pins the topic globally until a time in the given timezone", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "pinned_globally" => true,
            "pinned_until" => "2030-01-15 09:00",
            "timezone" => "Europe/Paris",
          },
        )

      expect(topic.reload).to have_attributes(pinned_globally: true, pinned_at: be_present)
      expect(topic.pinned_until).to eq_time(Time.utc(2030, 1, 15, 8))
      expect(result).to include(
        "changed" => true,
        "pinned_until" => "2030-01-15T08:00:00Z",
        "topic" => include("id" => topic.id, "pinned_globally" => true),
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "pins the topic in its category when pinned_globally is the string false" do
      execute_node(configuration: { "topic_id" => topic.id.to_s, "pinned_globally" => "false" })

      expect(topic.reload).to have_attributes(pinned_globally: false, pinned_at: be_present)
    end

    it "fires topic_status_updated with the actor" do
      event =
        DiscourseEvent.track(:topic_status_updated) do
          execute_node(configuration: { "topic_id" => topic.id.to_s })
        end

      expect(event[:params]).to eq([topic, "pinned", true, { acting_user: Discourse.system_user }])
    end

    it "rejects an actor who can't pin the topic" do
      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "actor_username" => user.username,
          },
        )
      end.to raise_error(DiscourseWorkflows::NodeError)

      expect(topic.reload.pinned_at).to be_nil
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnpinTopic::V1 do
  fab!(:topic)

  describe "#execute" do
    it "unpins a pinned topic and reports no change when it wasn't pinned", :aggregate_failures do
      topic.update_pinned(true)

      first = execute_node(configuration: { "topic_id" => topic.id.to_s })
      second = execute_node(configuration: { "topic_id" => topic.id.to_s })

      expect(topic.reload.pinned_at).to be_nil
      expect(first).to include("changed" => true, "topic" => include("id" => topic.id))
      expect(second).to include("changed" => false)
      expect(first).to match_node_output_schema(described_class)
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::MakeBanner::V1 do
  fab!(:topic)

  describe "#execute" do
    it "makes the topic the banner until a time", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "bannered_until" => "2030-01-15 09:00",
            "timezone" => "UTC",
          },
        )

      expect(topic.reload.archetype).to eq(Archetype.banner)
      expect(result).to include(
        "changed" => true,
        "bannered_until" => "2030-01-15T09:00:00Z",
        "topic" => include("id" => topic.id, "archetype" => Archetype.banner),
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "leaves the banner alone and reports no change when it already is the banner" do
      configuration = { "topic_id" => topic.id.to_s, "bannered_until" => "2030-01-15 09:00" }
      execute_node(configuration:)

      result = nil
      events = DiscourseEvent.track_events { result = execute_node(configuration:) }

      expect(events.map { |event| event[:event_name] }).not_to include(
        :topic_bannered,
        :topic_unbannered,
      )
      expect(result).to include("changed" => false)
    end

    it "rejects an actor who can't make the topic a banner" do
      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "actor_username" => Fabricate(:user).username,
          },
        )
      end.to raise_error(DiscourseWorkflows::NodeError)

      expect(topic.reload.archetype).to eq(Archetype.default)
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RemoveBanner::V1 do
  fab!(:topic)

  describe "#execute" do
    it "removes the banner and reports no change when it wasn't the banner", :aggregate_failures do
      topic.make_banner!(Discourse.system_user)

      first = execute_node(configuration: { "topic_id" => topic.id.to_s })
      second = execute_node(configuration: { "topic_id" => topic.id.to_s })

      expect(topic.reload.archetype).to eq(Archetype.default)
      expect(first).to include("changed" => true, "topic" => include("id" => topic.id))
      expect(second).to include("changed" => false)
      expect(first).to match_node_output_schema(described_class)
    end
  end
end
