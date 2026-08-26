# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../lib/discourse_workflows/nodes/event/v1"

RSpec.describe DiscourseWorkflows::Nodes::Event::V1 do
  fab!(:admin)

  before { SiteSetting.discourse_post_event_enabled = true }

  def create_event_post(closed: false)
    closed_attribute = closed ? ' closed="true"' : ""

    post =
      PostCreator.create!(
        admin,
        title: "Workflow event topic",
        raw:
          "[event start=\"2030-04-24 14:15\" end=\"2030-04-24 15:15\" timezone=\"UTC\"#{closed_attribute}]\n" \
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

  def execution_context(topic:, operation:)
    actor = admin

    Class
      .new do
        define_method(:initialize) do |topic_arg, operation_arg, actor_arg|
          @topic = topic_arg
          @operation = operation_arg
          @actor = actor_arg
        end

        define_method(:input_items) { [{ "json" => {} }] }

        define_method(:get_node_parameter) do |name, _item_index, default: nil|
          case name
          when "operation"
            @operation
          when "topic_id"
            @topic.id.to_s
          else
            default
          end
        end

        define_method(:actor_from_parameter) { |_name, _item_index| @actor }

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
      .new(topic, operation, actor)
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
end
