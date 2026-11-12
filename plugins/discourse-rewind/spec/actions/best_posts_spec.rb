# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::BestPosts do
  fab!(:user)
  fab!(:post_1) { Fabricate(:post, created_at: random_datetime, user: user, post_number: 3) }
  fab!(:post_2) { Fabricate(:post, created_at: random_datetime, user: user, post_number: 2) }
  fab!(:post_3) { Fabricate(:post, created_at: random_datetime, user: user, post_number: 10) }
  fab!(:post_4) { Fabricate(:post, created_at: random_datetime, user: user, post_number: 6) }
  fab!(:post_5) { Fabricate(:post, created_at: random_datetime, user: user, post_number: 1) }

  describe ".call" do
    it "returns top 3 posts ordered by like count" do
      post_4.update!(like_count: 15)
      post_3.update!(like_count: 13)
      post_1.update!(like_count: 11)
      post_2.update!(like_count: 9)
      post_5.update!(like_count: 7)

      expect(call_report[:data]).to eq(
        [post_4, post_3, post_1].map do |post|
          {
            post_number: post.post_number,
            topic_id: post.topic_id,
            like_count: post.like_count,
            reply_count: post.reply_count,
            excerpt: post.excerpt(200, { strip_links: true, remap_emoji: true, keep_images: true }),
          }
        end,
      )
    end

    it "only includes the user's publicly visible posts" do
      post_1.update!(user: Fabricate(:user))
      post_2.update!(topic: Fabricate(:private_message_topic, user:))

      expect(call_report[:data].pluck(:topic_id)).to contain_exactly(
        post_3.topic_id,
        post_4.topic_id,
      )
    end
  end

  describe ".filter_for_viewer" do
    it "only keeps public posts the viewer can see" do
      posts = [
        Fabricate(:post, hidden: true),
        Fabricate(:post, topic: Fabricate(:shared_draft).topic),
        post_1,
      ]
      report = {
        data: posts.map { |post| { topic_id: post.topic_id, post_number: post.post_number } },
        identifier: "best-posts",
      }

      filtered =
        described_class.filter_for_viewer(
          report,
          guardian: Fabricate(:user).guardian,
          for_user: user,
        )

      expect(filtered[:data]).to contain_exactly(
        topic_id: post_1.topic_id,
        post_number: post_1.post_number,
      )
    end
  end
end
