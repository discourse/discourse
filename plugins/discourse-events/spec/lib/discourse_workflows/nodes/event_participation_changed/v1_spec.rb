# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::EventParticipationChanged::V1 do
  fab!(:event)
  fab!(:user)

  let(:topic) { event.post.topic }
  let(:invitee) { DiscourseEvents::Events::Invitee.create_attendance!(user.id, event.id, :going) }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end

  it "returns the correct identifier" do
    expect(described_class.identifier).to eq("trigger:event_participation_changed")
  end

  describe "#valid?" do
    it "returns true for a newly created RSVP" do
      expect(described_class.new(invitee)).to be_valid
    end

    it "returns true when the status changed" do
      invitee.update_attendance!(:not_going)

      expect(described_class.new(invitee)).to be_valid
    end

    it "returns true when the RSVP was withdrawn" do
      invitee.destroy!

      expect(described_class.new(invitee)).to be_valid
    end

    it "returns false when the same status is submitted again" do
      invitee.update_attendance!(:going)

      expect(described_class.new(invitee)).not_to be_valid
    end

    it "returns false when the invitee is nil" do
      expect(described_class.new(nil)).not_to be_valid
    end

    it "returns false when events are disabled" do
      SiteSetting.discourse_post_event_enabled = false

      expect(described_class.new(invitee)).not_to be_valid
    end
  end

  describe "#output" do
    it "reports a new RSVP with no previous status", :aggregate_failures do
      output = described_class.new(invitee).output

      expect(output[:user][:username]).to eq(user.username)
      expect(output[:event][:id]).to eq(event.id)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:participation]).to include(
        status: "going",
        previous_status: nil,
        removed: false,
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "reports the status the user moved away from", :aggregate_failures do
      invitee.update_attendance!(:not_going)

      output = described_class.new(invitee).output

      expect(output[:participation]).to include(
        status: "not_going",
        previous_status: "going",
        removed: false,
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "reports a withdrawal with no current status", :aggregate_failures do
      invitee.destroy!

      output = described_class.new(invitee).output

      expect(output[:participation]).to include(
        status: nil,
        previous_status: "going",
        removed: true,
      )
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "matches every event when no topic is configured" do
      expect(described_class.new(invitee).matches?(trigger_context({}))).to eq(true)
    end

    it "matches the configured topic" do
      context = trigger_context("topic_id" => topic.id.to_s)

      expect(described_class.new(invitee).matches?(context)).to eq(true)
    end

    it "does not match another topic" do
      context = trigger_context("topic_id" => (topic.id + 1).to_s)

      expect(described_class.new(invitee).matches?(context)).to eq(false)
    end
  end
end
