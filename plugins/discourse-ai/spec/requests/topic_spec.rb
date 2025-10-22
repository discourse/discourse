# frozen_string_literal: true

describe ::TopicsController do
  fab!(:topic)
  fab!(:topic1, :topic)
  fab!(:topic2, :topic)
  fab!(:topic3, :topic)
  fab!(:user, :admin)

  before do
    enable_current_plugin

    SiteSetting.ai_embeddings_semantic_related_topics_enabled = true
    SiteSetting.ai_embeddings_semantic_related_topics = 2

    DiscourseAi::Embeddings::SemanticRelated
      .any_instance
      .stubs(:related_topic_ids_for)
      .returns([topic1.id, topic2.id, topic3.id])
  end

  context "when a user is logged on" do
    it "includes related topics in payload when configured" do
      get("#{topic.relative_url}.json")
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to eq(2)

      sign_in(user)

      get("#{topic.relative_url}.json")
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to eq(2)
    end

    it "includes related topics in payload when configured" do
      SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}"
      category = Fabricate(:category)
      topic.update!(category: category)

      get("#{topic.relative_url}.json")
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to eq(2)
      expect(json["categories"].map { |c| c["id"] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
        category.id,
      )
    end
  end

  describe "crawler" do
    let(:crawler_user_agent) do
      "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    end

    it "renders related topics in the crawler view" do
      get topic.relative_url, env: { "HTTP_USER_AGENT" => crawler_user_agent }
      body = response.body
      expect(body).to have_tag(:div, with: { id: "related-topics" })
      expect(body).to have_tag(:tr, with: { id: "topic-list-item-#{topic1.id}" })
      expect(body).to have_tag(:tr, with: { id: "topic-list-item-#{topic2.id}" })
    end
  end
end
