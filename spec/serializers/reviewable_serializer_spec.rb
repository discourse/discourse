# frozen_string_literal: true

RSpec.describe ReviewableSerializer do
  fab!(:reviewable, :reviewable_queued_post)
  fab!(:reviewable_user)
  fab!(:admin)

  it "serializes all the fields" do
    json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json

    expect(json[:id]).to eq(reviewable.id)
    expect(json[:status]).to eq(reviewable.status_for_database)
    expect(json[:type]).to eq(reviewable.type)
    expect(json[:type_source]).to eq(reviewable.type_source)
    expect(json[:created_at]).to eq(reviewable.created_at)
    expect(json[:category_id]).to eq(reviewable.category_id)
    expect(json[:can_edit]).to eq(true)
    expect(json[:version]).to eq(0)
    expect(json[:removed_topic_id]).to be_nil
    expect(json[:created_from_flag]).to eq(false)
  end

  it "Includes the removed topic id when the topis was deleted" do
    reviewable.topic.trash!(admin)
    json = described_class.new(reviewable.reload, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:removed_topic_id]).to eq reviewable.topic_id
  end

  it "will not throw an error when the payload is `nil`" do
    reviewable.payload = nil
    json =
      ReviewableQueuedPostSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json["payload"]).to be_blank
  end

  describe "urls" do
    it "links to the flagged post" do
      fp = Fabricate(:reviewable_flagged_post)
      json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_url]).to eq(Discourse.base_url + fp.post.url)
      expect(json[:topic_url]).to eq(fp.topic.url)
    end

    it "supports deleted topics" do
      fp = Fabricate(:reviewable_flagged_post)
      fp.topic.trash!(admin)
      fp.reload

      json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:topic_url]).to be_blank
    end

    it "links to the queued post" do
      json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_url]).to eq(reviewable.topic.url)
      expect(json[:topic_url]).to eq(reviewable.topic.url)
    end
  end

  describe "target_created_by" do
    it "serializes the user who created a reviewable post" do
      json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_created_by_id]).to eq(reviewable.target_created_by.id)
    end

    it "serializes a reviewable user directly" do
      json = described_class.new(reviewable_user, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_created_by_id]).to eq(reviewable_user.target.id)
    end
  end

  describe "target_deleted_by" do
    it "serializes when post was staff-deleted" do
      fp = Fabricate(:reviewable_flagged_post)
      fp.target.trash!(admin)
      fp.reload

      json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
      post = Post.with_deleted.find(fp.target_id)
      expect(json[:target_deleted_by_id]).to eq(admin.id)
      expect(json[:target_deleted_at]).to eq(post.deleted_at)
    end

    it "serializes when post was user-deleted" do
      fp = Fabricate(:reviewable_flagged_post)
      post = fp.target

      freeze_time do
        revision = post.revisions.create!(user: post.user, modifications: {})
        post.update!(user_deleted: true)
        fp.reload

        json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
        expect(json[:target_deleted_by_id]).to eq(post.user.id)
        expect(json[:target_deleted_at]).to eq_time(revision.created_at)
      end
    end
  end

  describe "topic_tags" do
    it "returns tag objects with id, name, and slug" do
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)
      reviewable.topic.tags = [tag]
      json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:topic_tags]).to eq([{ id: tag.id, name: tag.name, slug: tag.slug }])
    end
  end
end
