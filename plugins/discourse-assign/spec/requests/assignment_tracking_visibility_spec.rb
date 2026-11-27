# frozen_string_literal: true

RSpec.describe "Assignment tracking post visibility", type: :request do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:topic, :topic_with_op)
  fab!(:target) { Fabricate(:post, topic:, user: admin) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assigns_public = true
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    sign_in(admin)
    put "/assign/assign.json",
        params: {
          target_id: target.id,
          target_type: "Post",
          username: admin.username,
          note: "assignment tracking note",
        }
    expect(response.status).to eq(200)
  end

  def tracking_post
    Post.joins(:_custom_fields).find_by(
      post_custom_fields: {
        name: "action_code_post_id",
        value: target.id.to_s,
      },
    )
  end

  def expect_note_inaccessible(post_id)
    sign_in(reader)
    get "/posts/#{post_id}.json"
    expect(response.status).to eq(404)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    expect(
      response.parsed_body.dig("post_stream", "posts").map { |post| post["cooked"] }.join,
    ).not_to include("assignment tracking note")
  end

  it "restricts existing tracking posts when the target becomes a whisper" do
    tracking = tracking_post
    put "/posts/#{target.id}/post_type.json", params: { post_type: Post.types[:whisper] }
    expect(response.status).to eq(200)
    expect(reader.guardian.can_see_post?(target.reload)).to eq(false)
    expect_note_inaccessible(tracking.id)
    expect(tracking.reload).to be_whisper

    sign_in(admin)
    get "/posts/#{tracking.id}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["cooked"]).to include("assignment tracking note")
  end

  it "removes existing tracking posts when the target is hidden" do
    tracking = tracking_post
    target.hide!(PostActionType.types[:spam])
    expect(reader.guardian.can_see_post?(target.reload)).to eq(false)
    expect_note_inaccessible(tracking.id)
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
  end

  it "backfills a persisted public tracking note for a whisper target" do
    tracking = tracking_post
    # Simulate data written before audience selection and reconciliation existed.
    target.update_columns(post_type: Post.types[:whisper])
    require_relative "../../db/migrate/20261127000000_secure_assignment_tracking_posts"
    SecureAssignmentTrackingPosts.new.up
    SecureAssignmentTrackingPosts.new.up

    expect_note_inaccessible(tracking.id)
    expect(tracking.reload).to be_whisper
  end

  it "backfills a persisted tracking note for a hidden target, even for whisper readers" do
    tracking = tracking_post
    target.update_columns(hidden: true)
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    require_relative "../../db/migrate/20261127000000_secure_assignment_tracking_posts"
    SecureAssignmentTrackingPosts.new.up

    expect_note_inaccessible(tracking.id)
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
  end

  it "removes tracking posts moved away from their target" do
    tracking = tracking_post
    tracking.update!(post_type: Post.types[:whisper])
    destination = Fabricate(:topic_with_op)
    topic.move_posts(admin, [tracking.id], destination_topic_id: destination.id)
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
  end

  it "removes existing tracking posts when the target is deleted" do
    tracking = tracking_post
    delete "/posts/#{target.id}.json"
    expect(response.status).to eq(200)
    expect_note_inaccessible(tracking.id)
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
  end

  it "removes tracking posts left in the old topic when the target moves" do
    tracking = tracking_post
    group = Fabricate(:group)
    category = Fabricate(:private_category, group:)
    destination = Fabricate(:topic_with_op, category:)
    topic.move_posts(admin, [target.id], destination_topic_id: destination.id)
    expect(reader.guardian.can_see_post?(target.reload)).to eq(false)
    expect_note_inaccessible(tracking.id)
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
  end
end
