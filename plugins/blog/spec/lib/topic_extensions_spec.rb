# frozen_string_literal: true

RSpec.describe Blog::TopicExtensions do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin) }

  before { enable_blog!(category: category, drafts: drafts) }

  def issue_review
    issue_blog_review(topic, user: admin)
  end

  def unrevoked_reviews
    Blog::Review.where(topic: topic, revoked_at: nil)
  end

  def publish_discussion(path:, published: true)
    discussion = Fabricate(:topic, category: category)
    Fabricate(:post, topic: discussion)
    publication =
      Blog::Publication.create!(
        topic: discussion,
        path: path,
        published: published,
        published_at: (1.day.ago if published),
      )
    [discussion, publication]
  end

  describe "#blog_editorial_draft?" do
    it "is true for an open topic in the drafts category" do
      expect(topic.blog_editorial_draft?).to eq(true)
    end

    it "is false for unlisted, deleted and archived drafts, the drafts category's definition topic, and other categories" do
      unlisted = Fabricate(:topic, category: drafts, visible: false)
      deleted = Fabricate(:topic, category: drafts, deleted_at: Time.current)
      archived = Fabricate(:topic, category: drafts, archived: true)
      elsewhere = Fabricate(:topic, category: other_category)
      drafts.create_category_definition

      expect(
        [unlisted, deleted, archived, drafts.reload.topic, elsewhere].select(
          &:blog_editorial_draft?
        ),
      ).to be_empty
    end
  end

  describe "#blog_published_discussion?" do
    it "is true only for Blog-category topics whose publication has gone live" do
      live, _ = publish_discussion(path: "/live")
      unpublished, _ = publish_discussion(path: "/unpublished", published: false)

      expect([live, unpublished, topic].select(&:blog_published_discussion?)).to contain_exactly(
        live,
      )
    end
  end

  describe "#blog_live_publication" do
    it "returns the publicly visible publication for a discussion topic" do
      discussion, publication = publish_discussion(path: "/live")

      expect(discussion.blog_live_publication).to eq(publication)
    end

    it "returns nil when the site is not public" do
      discussion, _ = publish_discussion(path: "/live")
      SiteSetting.login_required = true

      expect(discussion.blog_live_publication).to be_nil
    end
  end

  describe "#destroy!" do
    it "destroys the topic's reviews" do
      review = issue_review

      topic.destroy!

      expect(Blog::Review.where(id: review.id)).not_to exist
    end

    it "destroys publications that reference the topic as source, draft, or discussion" do
      destroyed = Fabricate(:topic, category: other_category)
      sourced = Blog::Publication.create!(topic: destroyed, path: "/sourced")
      drafted =
        Blog::Publication.create!(
          topic: Fabricate(:topic, category: other_category),
          draft_topic: destroyed,
          path: "/drafted",
        )
      discussed =
        Blog::Publication.create!(
          topic: Fabricate(:topic, category: other_category),
          discussion_topic: destroyed,
          path: "/discussed",
        )
      unrelated =
        Blog::Publication.create!(
          topic: Fabricate(:topic, category: other_category),
          path: "/unrelated",
        )

      destroyed.destroy!

      expect(
        Blog::Publication.where(id: [sourced, drafted, discussed, unrelated]),
      ).to contain_exactly(unrelated)
    end

    it "keeps reviews and publications when the blog is disabled" do
      review = issue_review
      publication = Blog::Publication.create!(topic: topic, path: "/owned")
      SiteSetting.blog_enabled = false

      topic.destroy!

      expect(Blog::Review.where(id: review.id)).to exist
      expect(Blog::Publication.where(id: publication.id)).to exist
    end
  end

  describe "#save" do
    it "rejects moving a topic out of the drafts category" do
      topic.category_id = category.id

      expect(topic.save).to eq(false)
      expect(topic.errors[:category_id]).to contain_exactly(I18n.t("blog.editorial.private_source"))
      expect(topic.reload.category_id).to eq(drafts.id)
    end

    it "allows moving a topic into the drafts category" do
      other_topic = Fabricate(:topic, category: other_category)

      expect(other_topic.update(category_id: drafts.id)).to eq(true)
    end

    it "allows moving a topic out of the drafts category when the blog is disabled" do
      SiteSetting.blog_enabled = false

      expect(topic.update(category_id: category.id)).to eq(true)
    end
  end

  describe "#update!" do
    it "revokes reviews when the category changes" do
      issue_review

      topic.category_id = category.id
      topic.save!(validate: false)

      expect(unrevoked_reviews).to be_empty
    end

    it "revokes reviews when the topic is deleted" do
      issue_review

      topic.update!(deleted_at: Time.zone.now)

      expect(unrevoked_reviews).to be_empty
    end

    it "revokes reviews when the archetype changes" do
      issue_review

      topic.update!(archetype: Archetype.banner)

      expect(unrevoked_reviews).to be_empty
    end

    it "revokes reviews when the visibility changes" do
      issue_review

      topic.update!(visible: false)

      expect(unrevoked_reviews).to be_empty
    end

    it "keeps reviews when an unrelated attribute changes" do
      review = issue_review

      topic.update!(title: "A different title for the same draft")

      expect(unrevoked_reviews).to contain_exactly(review)
    end

    it "keeps reviews when the blog is disabled" do
      review = issue_review
      SiteSetting.blog_enabled = false

      topic.update!(visible: false)

      expect(unrevoked_reviews).to contain_exactly(review)
    end
  end
end
