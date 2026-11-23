# frozen_string_literal: true

module BlogReviewHelpers
  def issue_blog_review(topic, user:, label: "")
    Blog::Review::Create.call!(params: { topic_id: topic.id, label: }, guardian: user.guardian)[
      :review
    ]
  end

  def revoke_blog_review(review, user:)
    Blog::Review::Revoke.call!(
      params: {
        topic_id: review.topic_id,
        review_id: review.id,
      },
      guardian: user.guardian,
    )
  end

  def submit_blog_review_feedback(review, **feedback)
    Blog::Review::SubmitFeedback.call!(
      params: {
        review_id: review.id,
        feedback:,
      },
      guardian: Guardian.new,
    )[
      :review_feedback
    ]
  end
end

shared_context "with a reviewable blog draft" do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic:, user: admin) }

  before { enable_blog!(category:, drafts:) }
end

RSpec.configure { |config| config.include(BlogReviewHelpers) }
