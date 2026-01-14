# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::SentimentController do
  describe "#posts" do
    fab!(:admin)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:post_2) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:classification_result) { Fabricate(:classification_result, target: post) }

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
  end
end
