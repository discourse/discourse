# frozen_string_literal: true

RSpec.describe TagsController, type: :request do
  fab!(:sour) { Fabricate(:tag, name: "sour") }
  fab!(:tangy) { Fabricate(:tag, name: "tangy") }
  fab!(:matching_topic) { Fabricate(:topic, tags: [sour, tangy]) }
  fab!(:sour_topic) { Fabricate(:topic, tags: [sour]) }

  describe "#show" do
    before { SiteSetting.tagging_enabled = true }

    it "redirects repeated primary tags to unique intersections or the canonical single tag" do
      get "/tags/intersection/sour/tangy/sour"
      expect(response).to redirect_to("/tags/intersection/sour/tangy")
      follow_redirect!
      expect(response.status).to eq(200)

      get "/tags/intersection/sour/tangy/sour/sour"
      expect(response).to redirect_to("/tags/intersection/sour/tangy")
      follow_redirect!
      expect(response.status).to eq(200)

      get "/tags/intersection/sour/sour"
      expect(response).to redirect_to("/tag/sour")
      follow_redirect!
      expect(response).to redirect_to("/tag/#{sour.slug}/#{sour.id}")
      follow_redirect!
      expect(response.status).to eq(200)

      get "/tags/intersection/sour/tangy.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.dig("topic_list", "topics").map { |topic| topic["id"] },
      ).to contain_exactly(matching_topic.id)
      get "/tag/#{sour.slug}/#{sour.id}.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.dig("topic_list", "topics").map { |topic| topic["id"] },
      ).to contain_exactly(matching_topic.id, sour_topic.id)
    end

    it "redirects repeated additional tags to their unique intersection" do
      get "/tags/intersection/sour/tangy/tangy"
      expect(response).to redirect_to("/tags/intersection/sour/tangy")
      follow_redirect!
      expect(response.status).to eq(200)

      get "/tags/intersection/sour/tangy/tangy/tangy"
      expect(response).to redirect_to("/tags/intersection/sour/tangy")
      follow_redirect!
      expect(response.status).to eq(200)

      get "/tags/intersection/sour/tangy.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.dig("topic_list", "topics").map { |topic| topic["id"] },
      ).to contain_exactly(matching_topic.id)
    end
  end
end
