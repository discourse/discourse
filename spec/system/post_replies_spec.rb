# frozen_string_literal: true

describe "Post replies", type: :system do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, user:, topic:) }

  let(:first_post) { PageObjects::Components::Post.new(1) }
  let(:third_chained_reply) { PageObjects::Components::Post.new(7) }

  context "when loading post replies" do
    before do
      25.times do
        reply = Fabricate(:post, topic:, reply_to_post_number: 1)
        PostReply.create!(post:, reply:)
      end

      post.update!(reply_count: post.replies.count)
    end

    it "supports pagination" do
      sign_in(user)
      visit(topic.url)

      first_post.show_replies

      expect(first_post).to have_replies(count: 20)
      expect(first_post).to have_more_replies

      first_post.load_more_replies

      expect(first_post).to have_replies(count: post.replies.count)
      expect(first_post).to have_loaded_all_replies
    end
  end

  context "when loading parent posts" do
    before do
      SiteSetting.max_reply_history = 2

      3.times do |i|
        PostReply.create!(post:, reply: Fabricate(:post, topic:))

        reply = Fabricate(:post, topic:, reply_to_post_number: (i * 2) + 1, raw: "reply #{i + 1}")
        PostReply.create!(post:, reply:)
      end

      post.update!(reply_count: post.replies.count)
    end

    it "does not duplicate replies" do
      sign_in(user)
      visit(topic.url)

      third_chained_reply.show_parent_posts
      expect(third_chained_reply).to have_parent_posts(count: 2)
      expect(third_chained_reply).to have_no_parent_post_content("reply 3")
    end
  end
end
