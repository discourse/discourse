# frozen_string_literal: true

RSpec.describe "Assignment detail tracking visibility", type: :request do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:topic) { Fabricate(:topic_with_op, user: admin) }
  fab!(:target) { Fabricate(:post, topic:, user: admin) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assigns_public = true
    SiteSetting.enable_assign_status = true
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
  end

  shared_examples "restricted detail tracking" do |action_code, transition|
    it "restricts historical #{action_code} tracking for a #{transition} target" do
      tracking =
        Fabricate(
          :post,
          topic:,
          user: admin,
          raw: "historical assignment details",
          post_type: Post.types[:small_action],
          action_code:,
          custom_fields: {
            "action_code_post_id" => target.id,
            "action_code_path" => "/p/#{target.id}",
          },
        )
      restrict_target(transition, callbacks: false)

      require_relative "../../db/migrate/20261127000000_secure_assignment_tracking_posts"
      SecureAssignmentTrackingPosts.new.up

      expect_tracking_restricted(tracking, transition)
    end

    it "restricts #{action_code} tracking when the target becomes #{transition}" do
      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: target.id,
            target_type: "Post",
            username: admin.username,
            note: "original note",
            status: "New",
          }
      expect(response.status).to eq(200)

      put "/assign/assign.json",
          params: {
            target_id: target.id,
            target_type: "Post",
            username: admin.username,
            note: action_code == "status_change" ? "original note" : "updated note",
            status: action_code == "note_change" ? "New" : "Done",
          }
      expect(response.status).to eq(200)
      tracking = topic.posts.order(:post_number).last
      expect(tracking.action_code).to eq(action_code)

      sign_in(reader)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(stream_ids).to include(tracking.id)

      restrict_target(transition)

      expect_tracking_restricted(tracking, transition)
    end
  end

  it_behaves_like "restricted detail tracking", "note_change", :whisper
  it_behaves_like "restricted detail tracking", "note_change", :hidden
  it_behaves_like "restricted detail tracking", "note_change", :moved
  it_behaves_like "restricted detail tracking", "status_change", :whisper
  it_behaves_like "restricted detail tracking", "status_change", :hidden
  it_behaves_like "restricted detail tracking", "status_change", :moved
  it_behaves_like "restricted detail tracking", "details_change", :whisper
  it_behaves_like "restricted detail tracking", "details_change", :hidden
  it_behaves_like "restricted detail tracking", "details_change", :moved

  it_behaves_like "restricted detail tracking", "note_change", :trashed
  it_behaves_like "restricted detail tracking", "status_change", :trashed
  it_behaves_like "restricted detail tracking", "details_change", :trashed

  it "removes soft-deleted tracking posts when their target is deleted" do
    tracking = historical_tracking_post(deleted_at: 1.minute.ago)

    sign_in(admin)
    delete "/posts/#{target.id}.json"
    expect(response.status).to eq(200)
    expect(target.reload).to be_trashed
    expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
    expect(PostCustomField.exists?(post_id: tracking.id)).to eq(false)
  end

  it "does not expose historical tracking when it is recovered while its target is trashed" do
    target.trash!(admin)
    tracking = historical_tracking_post(deleted_at: 1.minute.ago)

    sign_in(admin)
    put "/posts/#{tracking.id}/recover.json"
    # Reconciliation permanently removes unsafe history, so there is no post to render.
    expect(response.status).to eq(404)

    expect_tracking_restricted(tracking, :trashed)
  end

  it "preserves recovery of tracking posts for visible targets" do
    tracking = historical_tracking_post(deleted_at: 1.minute.ago)

    sign_in(admin)
    put "/posts/#{tracking.id}/recover.json"
    expect(response.status).to eq(200)
    expect(tracking.reload).not_to be_trashed

    sign_in(reader)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    expect(stream_ids).to include(tracking.id)
  end

  it "reconciles historical tracking when a hidden target is recovered" do
    target.update!(hidden: true)
    target.trash!(admin)
    tracking = historical_tracking_post

    sign_in(admin)
    put "/posts/#{target.id}/recover.json"
    expect(response.status).to eq(200)
    expect(target.reload).not_to be_trashed

    expect_tracking_restricted(tracking, :hidden)
  end

  def historical_tracking_post(**attributes)
    Fabricate(
      :post,
      topic:,
      user: admin,
      raw: "historical confidential assignment note",
      post_type: Post.types[:small_action],
      action_code: "note_change",
      custom_fields: {
        "action_code_post_id" => target.id,
        "action_code_path" => "/p/#{target.id}",
      },
      **attributes,
    )
  end

  def restrict_target(transition, callbacks: true)
    if transition == :trashed && callbacks
      sign_in(admin)
      delete "/posts/#{target.id}.json"
      expect(response.status).to eq(200)
      return
    end

    attributes =
      case transition
      when :trashed
        { deleted_at: 1.minute.ago }
      when :whisper
        { post_type: Post.types[:whisper] }
      when :hidden
        { hidden: true }
      when :moved
        { topic_id: Fabricate(:private_message_topic, user: admin).id }
      end
    callbacks ? target.update!(attributes) : target.update_columns(attributes)
  end

  def expect_tracking_restricted(tracking, transition)
    sign_in(reader)
    expect(Guardian.new(reader).can_see_post?(target.reload)).to eq(false)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    expect(stream_ids).not_to include(tracking.id)

    if transition == :whisper
      expect(tracking.reload).to be_whisper
      sign_in(admin)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(stream_ids).to include(tracking.id)
    else
      expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
    end
  end

  def stream_ids
    response.parsed_body.dig("post_stream", "posts").map { |post| post["id"] }
  end
end
