# frozen_string_literal: true

RSpec.describe Blog::Review do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin) }

  let(:upload) { Fabricate(:upload, user: admin, created_at: 3.days.ago) }

  before do
    enable_blog!(category: category, drafts: drafts)
    first_post.update!(
      raw: "![Review image](#{upload.short_url})",
      cooked: "<p><img src=\"#{upload.url}\"></p>",
    )
    first_post.link_post_uploads
  end

  describe ".eligible_topic?" do
    it "returns true for a visible draft with a first post in the read-restricted drafts category" do
      expect(described_class.eligible_topic?(topic)).to eq(true)
    end

    it "returns false when the blog cannot be served publicly" do
      SiteSetting.login_required = true

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for a missing topic" do
      expect(described_class.eligible_topic?(nil)).to eq(false)
    end

    it "returns false for a deleted topic" do
      topic.trash!

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for an unlisted topic" do
      topic.update_columns(visible: false)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for a topic outside the drafts category" do
      topic.update_columns(category_id: category.id)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false when the drafts category is readable by everyone" do
      drafts.update_columns(read_restricted: false)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for a private message" do
      # The database forbids a categorised PM, so only the archetype changes in memory.
      topic.archetype = Archetype.private_message

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for a shared draft" do
      SharedDraft.create!(topic: topic, category: category)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false for a topic without a first post" do
      empty_topic = Fabricate(:topic, category: drafts, user: admin)

      expect(described_class.eligible_topic?(empty_topic)).to eq(false)
    end

    it "returns false when the first post is deleted" do
      first_post.update_columns(deleted_at: Time.current)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false when the first post is hidden" do
      first_post.update_columns(hidden: true)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns false when the topic is the discussion of a published article" do
      publication = Blog::Publication.create!(topic: topic, path: "/article")
      publication.update_columns(discussion_topic_id: topic.id, published: true)

      expect(described_class.eligible_topic?(topic)).to eq(false)
    end

    it "returns true when the topic is the discussion of an unpublished article" do
      publication = Blog::Publication.create!(topic: topic, path: "/article")
      publication.update_columns(discussion_topic_id: topic.id, published: false)

      expect(described_class.eligible_topic?(topic)).to eq(true)
    end
  end

  describe ".published_article_url" do
    fab!(:article_topic) { Fabricate(:topic, category: category, user: admin) }
    fab!(:article_post) { Fabricate(:post, topic: article_topic, user: admin) }

    def create_review(revoked_by_publish: true)
      described_class.create!(
        topic: topic,
        creator: admin,
        title: topic.title,
        cooked: "<p>Snapshot</p>",
        post_version: 1,
        token: SecureRandom.urlsafe_base64(32),
        expires_at: 1.day.from_now,
        revoked_at: Time.current,
        revoked_by_publish: revoked_by_publish,
      )
    end

    def publish_with_working_copy
      publication =
        Blog::Publication.create!(
          topic: article_topic,
          path: "/article",
          published: true,
          published_at: 1.day.ago,
        )
      publication.update!(draft_topic: topic)
      publication
    end

    it "returns nil for tokens that are not well-formed" do
      [nil, 123, "", "too-short", "#{"a" * 42}!"].each do |token|
        expect(described_class.published_article_url(token)).to be_nil
      end
    end

    it "returns nil for an unknown token" do
      publish_with_working_copy

      expect(described_class.published_article_url(SecureRandom.urlsafe_base64(32))).to be_nil
    end

    it "returns nil when the review was not closed by publishing" do
      publish_with_working_copy
      review = create_review(revoked_by_publish: false)

      expect(described_class.published_article_url(review.token)).to be_nil
    end

    it "returns nil while the article is not publicly visible" do
      publish_with_working_copy.update_columns(published: false)
      review = create_review

      expect(described_class.published_article_url(review.token)).to be_nil
    end

    it "returns the article URL when the reviewed topic is the publication's working copy" do
      publication = publish_with_working_copy
      review = create_review

      expect(described_class.published_article_url(review.token)).to eq(publication.url)
    end

    it "returns the article URL when the reviewed topic is the publication's source topic" do
      publication =
        Blog::Publication.create!(
          topic: topic,
          discussion_topic: article_topic,
          path: "/article",
          published: true,
          published_at: 1.day.ago,
        )
      publication.update_columns(draft_topic_id: nil)
      review = create_review

      expect(described_class.published_article_url(review.token)).to eq(publication.url)
    end
  end

  describe ".accessible_ids" do
    fab!(:user)

    let(:review) { issue_blog_review(topic, user: admin) }
    let!(:reviews) { [review, revoked_review, other_creator_review] }
    let(:revoked_review) do
      issue_blog_review(topic, user: admin).tap { |r| r.update!(revoked_at: Time.current) }
    end
    let(:other_creator_review) do
      issue_blog_review(topic, user: admin).tap { |r| r.update_columns(creator_id: user.id) }
    end

    it "returns current links whose creator can still edit the draft" do
      expect(described_class.accessible_ids(reviews, topic)).to eq([review.id])
    end

    it "returns nothing once the draft is no longer eligible" do
      first_post.update_columns(hidden: true)

      expect(described_class.accessible_ids(reviews, topic)).to be_empty
    end
  end

  describe "after create" do
    it "retains snapshot uploads after the working draft removes them" do
      review = issue_blog_review(topic, user: admin)
      first_post.update!(raw: "Image removed", cooked: "<p>Image removed</p>")
      first_post.link_post_uploads

      Jobs::CleanUpUploads.new.reset_last_cleanup!
      Jobs::CleanUpUploads.new.execute(nil)

      expect(review.reload).to be_accessible
      expect(review.cooked).to include(upload.url)
      expect(Upload.where(id: upload.id)).to exist
      expect(UploadReference.where(target: review).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe "after revocation" do
    it "releases snapshot references without removing the draft's references" do
      review = issue_blog_review(topic, user: admin)
      expect(UploadReference.where(target: review)).to exist

      review.update!(revoked_at: Time.current)

      expect(UploadReference.where(target: review)).not_to exist
      expect(UploadReference.where(target: first_post).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe ".revoke_for_topic!" do
    it "releases references for every revoked snapshot" do
      reviews = 2.times.map { issue_blog_review(topic, user: admin) }
      expect(UploadReference.where(target: reviews).count).to eq(2)

      described_class.revoke_for_topic!(topic.id)

      expect(described_class.where(id: reviews).where(revoked_at: nil)).not_to exist
      expect(UploadReference.where(target: reviews)).not_to exist
      expect(UploadReference.where(target: first_post).pluck(:upload_id)).to eq([upload.id])
    end
  end

  describe "#destroy!" do
    it "releases references when the snapshot is deleted" do
      review = issue_blog_review(topic, user: admin)
      expect(UploadReference.where(target: review)).to exist

      review.destroy!

      expect(UploadReference.where(target: review)).not_to exist
    end
  end
end
