# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../lib/discourse_workflows/nodes/event/v1"

RSpec.describe DiscourseWorkflows::Nodes::Event::V1 do
  fab!(:admin)
  fab!(:attendee, :user)

  before { SiteSetting.discourse_post_event_enabled = true }

  def create_event_post(closed: false)
    closed_attribute = closed ? ' closed="true"' : ""

    post =
      PostCreator.create!(
        admin,
        title: "Workflow event topic",
        raw:
          "[event start=\"2030-04-24 14:15\" end=\"2030-04-24 15:15\" timezone=\"UTC\" status=\"public\"#{closed_attribute}]\n" \
            "Event description\n" \
            "[/event]",
      )

    # In this isolated node spec, explicitly perform the same synchronization
    # that the Events plugin's post-created hook performs in normal operation.
    DiscourseEvents::Events::Event::SyncFromPost.call(params: { post_id: post.id })

    post.reload
    post.association(:event).reload
    post
  end

  def execution_context(topic:, operation:, attendee: nil, attendance: nil)
    actor = admin

    Class
      .new do
        define_method(
          :initialize,
        ) do |topic_arg, operation_arg, attendee_arg, attendance_arg, actor_arg|
          @topic = topic_arg
          @operation = operation_arg
          @attendee = attendee_arg
          @attendance = attendance_arg
          @actor = actor_arg
        end

        define_method(:input_items) { [{ "json" => {} }] }

        define_method(:get_node_parameter) do |name, _item_index, default: nil|
          case name
          when "operation"
            @operation
          when "topic_id"
            @topic.id.to_s
          when "attendee_username"
            @attendee&.username
          when "attendance"
            @attendance || default
          else
            default
          end
        end

        define_method(:actor_from_parameter) { |_name, _item_index| @actor }

        define_method(:find_user) { |username:| User.find_by(username:) }

        define_method(:edit_post) do |user:, post_id:, raw:|
          post = Post.find(post_id)

          revised = PostRevisor.new(post).revise!(user, { raw: raw }, skip_workflows: true)

          raise "Post revision failed: #{post.errors.full_messages.join(", ")}" if !revised

          # Emulate the Events plugin's :post_edited hook in this isolated
          # node spec so the Event model is synchronized from post.raw.
          DiscourseEvents::Events::Event::SyncFromPost.call(params: { post_id: post.id })

          post.reload
          post.association(:event).reload
          post
        end

        define_method(:serialize_topic) do |topic_arg, guardian:, **_options|
          { id: topic_arg.id, title: topic_arg.title }
        end

        define_method(:serialize_post) do |post, guardian:, **_options|
          { id: post.id, post_number: post.post_number }
        end
      end
      .new(topic, operation, attendee, attendance, actor)
  end

  it "closes the event by revising its source BBCode" do
    post = create_event_post
    topic = post.topic

    expect(post.event).to be_present
    expect(post.event.closed?).to eq(false)

    described_class.new(parameters: {}).execute(execution_context(topic: topic, operation: "close"))

    post.reload
    post.association(:event).reload

    expect(post.raw).to include('closed="true"')
    expect(post.event.closed?).to eq(true)
  end

  it "opens a closed event by removing the closed attribute" do
    post = create_event_post(closed: true)
    topic = post.topic

    expect(post.event).to be_present
    expect(post.event.closed?).to eq(true)

    described_class.new(parameters: {}).execute(execution_context(topic: topic, operation: "open"))

    post.reload
    post.association(:event).reload

    expect(post.raw).not_to match(/\sclosed\s*=/i)
    expect(post.event.closed?).to eq(false)
  end

  it "does not confuse closed= text inside another quoted attribute with the closed attribute" do
    node = described_class.new(parameters: {})

    raw =
      "[event start=\"2030-04-24 14:15\" location=\"Room closed=true\"]\n" \
        "Description\n" \
        "[/event]"

    updated = node.send(:raw_with_closed_state, raw, closed: true)

    expect(updated).to include('location="Room closed=true"')
    expect(updated).to include(' closed="true"]')
  end

  it "preserves another quoted attribute while opening an event" do
    node = described_class.new(parameters: {})

    raw =
      "[event start=\"2030-04-24 14:15\" location=\"Room closed=true\" closed=\"true\"]\n" \
        "Description\n" \
        "[/event]"

    updated = node.send(:raw_with_closed_state, raw, closed: false)

    expect(updated).to include('location="Room closed=true"')
    expect(updated).not_to match(/\sclosed\s*=\s*["']true["']/i)
  end

  it "is idempotent when the event is already closed" do
    post = create_event_post(closed: true)
    original_raw = post.raw.dup

    described_class.new(parameters: {}).execute(
      execution_context(topic: post.topic, operation: "close"),
    )

    expect(post.reload.raw).to eq(original_raw)
    expect(post.event.closed?).to eq(true)
  end

  it "creates attendance for a user" do
    post = create_event_post

    expect(post.event.invitees.find_by(user_id: attendee.id)).to be_nil

    described_class.new(parameters: {}).execute(
      execution_context(
        topic: post.topic,
        operation: "set_attendance",
        attendee: attendee,
        attendance: "going",
      ),
    )

    invitee = post.event.invitees.find_by(user_id: attendee.id)

    expect(invitee).to be_present
    expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
  end

  it "updates existing attendance for a user" do
    post = create_event_post
    invitee =
      DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, post.event.id, :interested)

    described_class.new(parameters: {}).execute(
      execution_context(
        topic: post.topic,
        operation: "set_attendance",
        attendee: attendee,
        attendance: "going",
      ),
    )

    expect(invitee.reload.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
  end

  it "removes attendance for a user" do
    post = create_event_post
    DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, post.event.id, :going)

    described_class.new(parameters: {}).execute(
      execution_context(
        topic: post.topic,
        operation: "set_attendance",
        attendee: attendee,
        attendance: "remove",
      ),
    )

    expect(post.event.invitees.find_by(user_id: attendee.id)).to be_nil
  end

  it "does not update attendance when it already matches" do
    post = create_event_post
    invitee =
      DiscourseEvents::Events::Invitee.create_attendance!(attendee.id, post.event.id, :going)

    allow(DiscourseEvents::Events::UpdateInvitee).to receive(:call).and_call_original

    described_class.new(parameters: {}).execute(
      execution_context(
        topic: post.topic,
        operation: "set_attendance",
        attendee: attendee,
        attendance: "going",
      ),
    )

    expect(DiscourseEvents::Events::UpdateInvitee).not_to have_received(:call)
    expect(invitee.reload.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
  end

  it "does nothing when removing attendance that does not exist" do
    post = create_event_post

    allow(DiscourseEvents::Events::DestroyInvitee).to receive(:call).and_call_original

    described_class.new(parameters: {}).execute(
      execution_context(
        topic: post.topic,
        operation: "set_attendance",
        attendee: attendee,
        attendance: "remove",
      ),
    )

    expect(DiscourseEvents::Events::DestroyInvitee).not_to have_received(:call)
    expect(post.event.invitees.find_by(user_id: attendee.id)).to be_nil
  end

  it "fails when setting Going on an event at capacity" do
    post = create_event_post
    event = post.event
    event.update!(max_attendees: 1)

    event.create_invitees(
      [{ user_id: admin.id, status: DiscourseEvents::Events::Invitee.statuses[:going] }],
    )

    expect do
      described_class.new(parameters: {}).execute(
        execution_context(
          topic: post.topic,
          operation: "set_attendance",
          attendee: attendee,
          attendance: "going",
        ),
      )
    end.to raise_error(DiscourseWorkflows::NodeError) do |error|
      expect(error.message).to include("Could not update event attendance.")
      expect(error.message).to include("[policy] has_capacity")
    end

    expect(event.invitees.find_by(user_id: attendee.id)).to be_nil
  end
end
