# frozen_string_literal: true

RSpec.describe Blog::PostExtensions do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: admin) }

  before { enable_blog!(category: category, drafts: drafts) }

  def issue_review
    issue_blog_review(topic, user: admin)
  end

  def unrevoked_reviews
    Blog::Review.where(topic: topic, revoked_at: nil)
  end

  describe "#update!" do
    it "revokes reviews when the first post is hidden" do
      issue_review

      first_post.update!(hidden: true)

      expect(unrevoked_reviews).to be_empty
    end

    it "revokes reviews when the first post is deleted" do
      issue_review

      first_post.update!(deleted_at: Time.zone.now)

      expect(unrevoked_reviews).to be_empty
    end

    it "keeps reviews when a reply is hidden or deleted" do
      review = issue_review

      reply.update!(hidden: true)
      reply.update!(deleted_at: Time.zone.now)

      expect(unrevoked_reviews).to contain_exactly(review)
    end

    it "keeps reviews when the first post is edited" do
      review = issue_review

      first_post.update!(raw: "A revised draft that stays under review.")

      expect(unrevoked_reviews).to contain_exactly(review)
    end

    it "keeps reviews when the blog is disabled" do
      review = issue_review
      SiteSetting.blog_enabled = false

      first_post.update!(hidden: true)

      expect(unrevoked_reviews).to contain_exactly(review)
    end
  end
end
