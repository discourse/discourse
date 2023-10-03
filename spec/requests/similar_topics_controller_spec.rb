# frozen_string_literal: true

RSpec.describe SimilarTopicsController do
  describe "similar_to" do
    let(:title) { "this title is long enough to search for" }
    let(:raw) { "this body is long enough to search for" }

    let(:topic) { Fabricate(:topic, title: title) }
    let(:post) { Fabricate(:post, topic: topic, raw: raw, post_number: 1) }

    let(:private_post) { Fabricate(:post, raw: raw, topic: private_topic, post_number: 1) }
    let(:private_topic) do
      Fabricate(
        :topic,
        title: "#{title} 02",
        category: Fabricate(:private_category, group: Group[:staff]),
      )
    end

    def reindex_posts
      with_search_indexer_enabled { Jobs::ReindexSearch.new.rebuild_posts }
    end

    it "requires a title param" do
      get "/topics/similar_to.json", params: { raw: raw }
      expect(response.status).to eq(400)
    end

    it "returns no results if the title length is below the minimum" do
      SiteSetting.minimum_topics_similar = 0
      SiteSetting.min_title_similar_length = 100
      post
      reindex_posts

      get "/topics/similar_to.json", params: { title: title, raw: raw }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["similar_topics"].size).to eq(0)
    end

    describe "minimum_topics_similar" do
      before { SiteSetting.minimum_topics_similar = 30 }

      context "with enough topics" do
        it "deletes to Topic.similar_to if there are more topics than `minimum_topics_similar`" do
          Topic.stubs(:count).returns(50)
          post
          reindex_posts

          get "/topics/similar_to.json", params: { title: title, raw: raw }

          expect(response.status).to eq(200)
          similar_topics = response.parsed_body["similar_topics"]
          expect(similar_topics.size).to eq(1)
          expect(similar_topics.first["topic_id"]).to eq(topic.id)
        end

        context "with a logged in user" do
          before do
            private_post
            post
            reindex_posts
            Topic.stubs(:count).returns(50)
            sign_in(Fabricate(:moderator))
            Group.refresh_automatic_groups!
          end

          it "passes a user through if logged in" do
            get "/topics/similar_to.json", params: { title: title, raw: raw }

            expect(response.status).to eq(200)
            similar_topics =
              response.parsed_body["similar_topics"].map { |topic| topic["topic_id"] }
            expect(similar_topics.size).to eq(2)
            expect(similar_topics).to include(topic.id)
            expect(similar_topics).to include(private_topic.id)
          end
        end
      end

      it "does not call Topic.similar_to if there are fewer topics than `minimum_topics_similar`" do
        Topic.stubs(:count).returns(10)
        post
        reindex_posts

        get "/topics/similar_to.json", params: { title: title, raw: raw }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["similar_topics"].size).to eq(0)
      end
    end
  end
end
