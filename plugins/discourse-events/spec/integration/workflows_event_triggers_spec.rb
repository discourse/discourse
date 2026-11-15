# frozen_string_literal: true

RSpec.describe "Post event workflow triggers" do
  fab!(:admin)
  fab!(:attendee) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:event) { Fabricate(:event, original_starts_at: 7.days.from_now) }
  # Far enough out that it never ends inside the frozen window below.
  fab!(:other_event) { Fabricate(:event, original_starts_at: 30.days.from_now) }

  let(:topic) { event.post.topic }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  def publish_workflow(node_id, identifier, configuration = {})
    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      **build_workflow_graph { |graph| graph.node node_id, identifier, configuration: },
    )
  end

  def enqueued_workflow_ids(*node_ids)
    Jobs::DiscourseWorkflows::ExecuteWorkflow
      .jobs
      .map { |job| job["args"].first }
      .select { |args| args["trigger_node_id"].in?(node_ids) }
      .map { |args| args["workflow_id"] }
  end

  describe "trigger:event_participation_changed" do
    it "enqueues workflows matching the event's topic when a user RSVPs" do
      all_events = publish_workflow("trigger-all", "trigger:event_participation_changed")
      this_topic =
        publish_workflow(
          "trigger-topic",
          "trigger:event_participation_changed",
          { "topic_id" => topic.id.to_s },
        )
      publish_workflow(
        "trigger-other",
        "trigger:event_participation_changed",
        { "topic_id" => other_event.post.topic.id.to_s },
      )

      DiscourseEvents::Events::CreateInvitee.call(
        params: {
          event_id: event.id,
          user_id: attendee.id,
          status: "going",
        },
        guardian: attendee.guardian,
      )

      expect(
        enqueued_workflow_ids("trigger-all", "trigger-topic", "trigger-other"),
      ).to contain_exactly(all_events.id, this_topic.id)
    end

    it "enqueues once when a user withdraws their RSVP" do
      invitee = DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, event.id, :going)
      workflow = publish_workflow("trigger-all", "trigger:event_participation_changed")
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

      DiscourseEvents::Events::DestroyInvitee.call(
        params: {
          post_id: event.id,
          id: invitee.id,
        },
        guardian: attendee.guardian,
      )

      expect(enqueued_workflow_ids("trigger-all")).to eq([workflow.id])

      trigger_data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first["trigger_data"]
      expect(trigger_data["participation"]).to include("removed" => true, "status" => nil)
    end

    it "enqueues for each invitee whose status a bulk invite sets" do
      event.update!(status: DiscourseEvents::Events::Event.statuses[:public])
      newcomer = Fabricate(:user)
      DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, event.id, :interested)
      workflow = publish_workflow("trigger-all", "trigger:event_participation_changed")
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

      Jobs::DiscoursePostEventBulkInvite.new.execute(
        event_id: event.id,
        current_user_id: admin.id,
        invitees: [
          { "identifier" => attendee.username, "attendance" => "going" },
          { "identifier" => newcomer.username, "attendance" => "not_going" },
        ],
      )

      expect(enqueued_workflow_ids("trigger-all")).to eq([workflow.id, workflow.id])

      participations =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
          job["args"].first["trigger_data"].slice("user", "participation", "actor")
        end
      expect(participations).to contain_exactly(
        a_hash_including(
          "user" => a_hash_including("id" => attendee.id),
          "participation" =>
            a_hash_including("status" => "going", "previous_status" => "interested"),
          "actor" => a_hash_including("id" => admin.id),
        ),
        a_hash_including(
          "user" => a_hash_including("id" => newcomer.id),
          "participation" => a_hash_including("status" => "not_going", "previous_status" => nil),
          "actor" => a_hash_including("id" => admin.id),
        ),
      )
    end

    it "does not enqueue when a bulk invite leaves the status unchanged" do
      event.update!(status: DiscourseEvents::Events::Event.statuses[:public])
      DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, event.id, :going).update!(
        notified: true,
      )
      publish_workflow("trigger-all", "trigger:event_participation_changed")
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

      Jobs::DiscoursePostEventBulkInvite.new.execute(
        event_id: event.id,
        current_user_id: admin.id,
        invitees: [{ "identifier" => attendee.username, "attendance" => "going" }],
      )

      expect(enqueued_workflow_ids("trigger-all")).to be_empty
    end
  end

  describe "trigger:event_ended" do
    it "enqueues workflows matching the event's topic when an occurrence ends" do
      all_events = publish_workflow("trigger-all", "trigger:event_ended")
      this_topic =
        publish_workflow("trigger-topic", "trigger:event_ended", { "topic_id" => topic.id.to_s })
      publish_workflow(
        "trigger-other",
        "trigger:event_ended",
        { "topic_id" => other_event.post.topic.id.to_s },
      )

      freeze_time 8.days.from_now
      Jobs::DiscourseCalendar::MonitorEventDates.new.execute({})

      expect(
        enqueued_workflow_ids("trigger-all", "trigger-topic", "trigger-other"),
      ).to contain_exactly(all_events.id, this_topic.id)
    end
  end
end
