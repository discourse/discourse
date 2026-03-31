# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::SentimentController do
  describe "#posts" do
    fab!(:admin)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:post_2) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:classification_result) { Fabricate(:sentiment_classification, target: post) }

    before do
      enable_current_plugin
      SiteSetting.ai_sentiment_enabled = true
      sign_in(admin)
    end

    it "returns a posts based on params" do
      post.reload
      classification_result.reload

      get "/discourse-ai/sentiment/posts",
          params: {
            group_by: "category",
            group_value: category.name,
            threshold: 0.0,
          }

      expect(response).to be_successful

      post_response = JSON.parse(response.body)
      posts = post_response["posts"]
      posts.each do |post|
        expect(post).to have_key("sentiment")
        expect(post["sentiment"]).to match(/positive|negative|neutral/)
      end
    end

    context "when signed in as a moderator" do
      fab!(:moderator)

      it "excludes posts from categories the moderator cannot see when group_by is category" do
        restricted_category = Fabricate(:category)
        restricted_category.set_permissions(admins: :full)
        restricted_category.save!

        restricted_topic = Fabricate(:topic, category: restricted_category)
        restricted_post = Fabricate(:post, user: admin, topic: restricted_topic)
        Fabricate(:sentiment_classification, target: restricted_post)

        sign_in(moderator)

        get "/discourse-ai/sentiment/posts",
            params: {
              group_by: "category",
              group_value: restricted_category.name,
            }

        expect(response).to be_successful
        post_ids = JSON.parse(response.body)["posts"].map { |p| p["post_id"] }
        expect(post_ids).not_to include(restricted_post.id)
      end

      it "excludes posts from categories the moderator cannot see when group_by is tag" do
        restricted_category = Fabricate(:category)
        restricted_category.set_permissions(admins: :full)
        restricted_category.save!

        tag = Fabricate(:tag, name: "secret-tag")
        restricted_topic = Fabricate(:topic, category: restricted_category, tags: [tag])
        restricted_post = Fabricate(:post, user: admin, topic: restricted_topic)
        Fabricate(:sentiment_classification, target: restricted_post)

        sign_in(moderator)

        get "/discourse-ai/sentiment/posts", params: { group_by: "tag", group_value: "secret-tag" }

        expect(response).to be_successful
        post_ids = JSON.parse(response.body)["posts"].map { |p| p["post_id"] }
        expect(post_ids).not_to include(restricted_post.id)
      end
    end

    it "excludes posts from soft-deleted topics" do
      deleted_topic = Fabricate(:topic, category: category, deleted_at: Time.current)
      deleted_topic_post = Fabricate(:post, user: admin, topic: deleted_topic)
      Fabricate(:sentiment_classification, target: deleted_topic_post)

      live_topic_post = Fabricate(:post, user: admin, topic: topic)
      Fabricate(:sentiment_classification, target: live_topic_post)

      get "/discourse-ai/sentiment/posts",
          params: {
            group_by: "category",
            group_value: category.name,
          }

      expect(response).to be_successful

      post_ids = JSON.parse(response.body)["posts"].map { |p| p["post_id"] }
      expect(post_ids).to include(live_topic_post.id)
      expect(post_ids).not_to include(deleted_topic_post.id)
    end
  end
end
