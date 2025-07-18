# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

RSpec.describe TopicViewSerializer do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new(user) }

  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    add_to_assign_allowed_group(user)
  end

  it "includes assigned user in serializer" do
    Assigner.new(topic, user).assign(user)
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assigned_to_user][:name]).to eq(user.name)
    expect(serializer.as_json[:topic_view][:assigned_to_user][:username]).to eq(user.username)
    expect(serializer.as_json[:topic_view][:assigned_to_group]).to be nil
  end

  it "includes assigned group in serializer" do
    Assigner.new(topic, user).assign(assign_allowed_group)
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assigned_to_group][:name]).to eq(
      assign_allowed_group.name,
    )
    expect(serializer.as_json[:topic_view][:assigned_to_user]).to be nil
  end

  it "includes note in serializer" do
    Assigner.new(topic, user).assign(user, note: "note me down")
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assignment_note]).to eq("note me down")
  end

  it "includes indirectly_assigned_to notes in serializer" do
    Assigner.new(post, user).assign(user, note: "note me down")
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(
      serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_note],
    ).to eq("note me down")
  end

  context "when status is enabled" do
    before { SiteSetting.enable_assign_status = true }

    it "includes status in serializer" do
      Assigner.new(topic, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(serializer.as_json[:topic_view][:assignment_status]).to eq("Done")
    end

    it "includes indirectly_assigned_to status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(
        serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_status],
      ).to eq("Done")
    end
  end

  context "when status is disabled" do
    before { SiteSetting.enable_assign_status = false }

    it "doesn't include status in serializer" do
      Assigner.new(topic, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(serializer.as_json[:topic_view][:assignment_status]).not_to eq("Done")
    end

    it "doesn't include indirectly_assigned_to status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(
        serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_status],
      ).not_to eq("Done")
    end
  end
end
