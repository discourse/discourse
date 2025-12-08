# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::BestPosts do
  fab!(:date) { Date.new(2021).all_year }
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
        [
          {
            post_number: post_4.post_number,
            topic_id: post_4.topic_id,
            like_count: post_4.like_count,
            reply_count: post_4.reply_count,
            excerpt:
              post_4.excerpt(200, { strip_links: true, remap_emoji: true, keep_images: true }),
          },
          {
            post_number: post_3.post_number,
            topic_id: post_3.topic_id,
            like_count: post_3.like_count,
            reply_count: post_3.reply_count,
            excerpt:
              post_3.excerpt(200, { strip_links: true, remap_emoji: true, keep_images: true }),
          },
          {
            post_number: post_1.post_number,
            topic_id: post_1.topic_id,
            like_count: post_1.like_count,
            reply_count: post_1.reply_count,
            excerpt:
              post_1.excerpt(200, { strip_links: true, remap_emoji: true, keep_images: true }),
          },
        ],
      )
    end

    context "when a post is deleted" do
      before { post_1.trash!(Discourse.system_user) }

      it "is not included" do
        expect(call_report[:data].map { |d| d[:post_number] }).not_to include(post_1.post_number)
      end
    end

    context "when a post is made by another user" do
      before { post_1.update!(user: Fabricate(:user)) }

      it "is not included" do
        expect(call_report[:data].map { |d| d[:post_number] }).not_to include(post_1.post_number)
      end
    end
  end
end
