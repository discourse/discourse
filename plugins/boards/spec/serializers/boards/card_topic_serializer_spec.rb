# frozen_string_literal: true

RSpec.describe Boards::CardTopicSerializer do
  fab!(:assigner, :user)
  fab!(:viewer, :user)
  fab!(:assignee, :user)
  fab!(:hidden_post_assignee, :user)
  fab!(:assign_group, :group)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:regular_post) { Fabricate(:post, topic:) }
  fab!(:whisper) { Fabricate(:post, topic:, post_type: Post.types[:whisper]) }

  before do
    enable_current_plugin
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
    assign_group.add(assigner)
  end

  it "serializes a Unicode topic title" do
    topic.update!(title: "Launch :rocket:")

    payload = described_class.new(topic, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload).to include(title: "Launch :rocket:", unicode_title: "Launch 🚀")
  end

  it "hides assignment metadata from unauthorized users" do
    Fabricate(:topic_assignment, topic:, assigned_to: assignee)

    payload = described_class.new(topic, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload.keys).not_to include(
      :assigned_to_user,
      :assigned_to_group,
      :all_assigned_users,
      :assignments,
    )
  end

  it "shows assignment metadata to users who can assign" do
    topic_assignment = Fabricate(:topic_assignment, topic:, assigned_to: assignee)

    payload = described_class.new(topic, root: false, scope: Guardian.new(assigner)).as_json

    expect(payload).to include(
      assigned_to_user: include(username: assignee.username),
      all_assigned_users: contain_exactly(include(username: assignee.username)),
      assignments:
        contain_exactly(
          include(
            target_type: "Topic",
            target_id: topic_assignment.target_id,
            username: assignee.username,
          ),
        ),
    )
  end

  it "filters post assignments by post visibility" do
    SiteSetting.assigns_public = true
    visible_post_assignment = Fabricate(:post_assignment, post: regular_post, assigned_to: assignee)
    Fabricate(:post_assignment, post: whisper, assigned_to: hidden_post_assignee)

    payload = described_class.new(topic, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload).to include(
      all_assigned_users: contain_exactly(include(username: assignee.username)),
      assignments:
        contain_exactly(
          include(
            target_type: "Post",
            target_id: visible_post_assignment.target_id,
            post_number: regular_post.post_number,
            username: assignee.username,
          ),
        ),
    )
  end
end
