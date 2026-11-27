# frozen_string_literal: true

RSpec.describe DiscourseAssign::TrackingPostVisibility do
  fab!(:admin)
  fab!(:topic)
  fab!(:target) { Fabricate(:post, topic:, user: admin) }

  def tracking_post(action_code: "assigned_to_post", **attributes)
    Fabricate(
      :post,
      topic:,
      user: admin,
      post_type: Post.types[:small_action],
      action_code:,
      custom_fields: {
        "action_code_post_id" => target.id,
        "action_code_path" => "/p/#{target.id}",
      },
      **attributes,
    )
  end

  def backfill!
    require_relative "../../../db/migrate/20261127000000_secure_assignment_tracking_posts"
    SecureAssignmentTrackingPosts.new.up
  end

  describe "backfill migration" do
    it "restricts all historical assignment action codes without requiring an active assignment" do
      tracking_posts =
        described_class::ACTION_CODES.map { |action_code| tracking_post(action_code:) }
      target.update_columns(post_type: Post.types[:whisper])
      backfill!
      expect(tracking_posts.map { |tracking| tracking.reload.post_type }).to all(
        eq(Post.types[:whisper]),
      )
    end

    it "removes soft-deleted tracking posts for hidden targets rather than leaving a recovery path" do
      tracking = tracking_post(deleted_at: 1.minute.ago, post_type: Post.types[:whisper])
      target.update_columns(hidden: true)
      backfill!
      expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
      expect(PostCustomField.exists?(post_id: tracking.id)).to eq(false)
    end

    it "removes tracking posts for missing, deleted, or cross-topic targets" do
      tracking = tracking_post
      target.update_columns(deleted_at: 1.minute.ago)
      backfill!
      expect(Post.with_deleted.exists?(tracking.id)).to eq(false)

      target.update_columns(deleted_at: nil)
      tracking = tracking_post
      target.update_columns(topic_id: Fabricate(:topic).id)
      backfill!
      expect(Post.with_deleted.exists?(tracking.id)).to eq(false)

      tracking = tracking_post
      target.destroy!
      backfill!
      expect(Post.with_deleted.exists?(tracking.id)).to eq(false)
    end

    it "preserves public tracking posts, existing whispers, and unrelated action codes" do
      public_tracking = tracking_post
      whisper_tracking = tracking_post(post_type: Post.types[:whisper])
      unrelated_tracking = tracking_post(action_code: "split_topic")
      backfill!
      expect(public_tracking.reload.post_type).to eq(Post.types[:small_action])
      expect(whisper_tracking.reload).to be_whisper
      expect(unrelated_tracking.reload.post_type).to eq(Post.types[:small_action])
    end
  end

  it "does not widen historical tracking whispers when the target becomes regular" do
    target.update!(post_type: Post.types[:whisper])
    tracking = tracking_post(post_type: Post.types[:whisper])
    target.update!(post_type: Post.types[:regular])
    expect(tracking.reload).to be_whisper
  end
end
