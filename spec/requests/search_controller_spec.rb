# frozen_string_literal: true

RSpec.describe SearchController do
  fab!(:awesome_topic) do
    topic = Fabricate(:topic)
    tag = Fabricate(:tag)
    topic.tags << tag
    Fabricate(:tag, target_tag_id: tag.id)
    topic
  end

  fab!(:awesome_post) do
    with_search_indexer_enabled do
      Fabricate(:post, topic: awesome_topic, raw: "this is my really awesome post")
    end
  end

  fab!(:awesome_post_2) do
    with_search_indexer_enabled { Fabricate(:post, raw: "this is my really awesome post 2") }
  end

  fab!(:user) { with_search_indexer_enabled { Fabricate(:user) } }

  fab!(:user_post) do
    with_search_indexer_enabled { Fabricate(:post, raw: "#{user.username} is a cool person") }
  end

  context "with integration" do
    before { SearchIndexer.enable }

    before do
      # TODO be a bit more strategic here instead of junking
      # all of redis
      Discourse.redis.flushdb
    end

    after { Discourse.redis.flushdb }

    context "when overloaded" do
      before { global_setting :disable_search_queue_threshold, 0.2 }

      let! :start_time do
        freeze_time
        Time.now
      end

      let! :current_time do
        freeze_time 0.3.seconds.from_now
      end

      it "errors on #query" do
        get "/search/query.json",
            headers: {
              "HTTP_X_REQUEST_START" => "t=#{start_time.to_f}",
            },
            params: {
              term: "hi there",
            }

        expect(response.status).to eq(409)
      end

      it "no results and error on #index" do
        get "/search.json",
            headers: {
              "HTTP_X_REQUEST_START" => "t=#{start_time.to_f}",
            },
            params: {
              q: "awesome",
            }

        expect(response.status).to eq(200)

        data = response.parsed_body

        expect(data["posts"]).to be_empty
        expect(data["grouped_search_result"]["error"]).not_to be_empty
      end
    end

    it "returns a 400 error if you search for null bytes" do
      term = "hello\0hello"

      get "/search/query.json", params: { term: term }

      expect(response.status).to eq(400)
    end

    it "can search correctly" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      awesome_post_3 = Fabricate(:post, topic: Fabricate(:topic, title: "this is an awesome title"))

      get "/search/query.json", params: { term: "awesome" }

      expect(response.status).to eq(200)

      data = response.parsed_body

      expect(data["posts"].length).to eq(3)

      expect(data["posts"][0]["id"]).to eq(awesome_post_3.id)
      expect(data["posts"][0]["blurb"]).to eq(awesome_post_3.raw)
      expect(data["posts"][0]["topic_title_headline"]).to eq(
        "This is an <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">awesome</span> title",
      )
      expect(data["topics"][0]["id"]).to eq(awesome_post_3.topic_id)

      expect(data["posts"][1]["id"]).to eq(awesome_post_2.id)
      expect(data["posts"][1]["blurb"]).to eq(
        "#{Search::GroupedSearchResults::OMISSION}this is my really <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">awesome</span> post#{Search::GroupedSearchResults::OMISSION}",
      )
      expect(data["topics"][1]["id"]).to eq(awesome_post_2.topic_id)

      expect(data["posts"][2]["id"]).to eq(awesome_post.id)
      expect(data["posts"][2]["blurb"]).to eq(
        "this is my really <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">awesome</span> post",
      )
      expect(data["topics"][2]["id"]).to eq(awesome_post.topic_id)
    end

    it "can search correctly with advanced search filters" do
      awesome_post.update!(raw: "#{"a" * Search::GroupedSearchResults::BLURB_LENGTH} elephant")

      get "/search/query.json", params: { term: "order:views elephant" }

      expect(response.status).to eq(200)

      data = response.parsed_body

      expect(data.dig("grouped_search_result", "term")).to eq("order:views elephant")
      expect(data["posts"].length).to eq(1)
      expect(data["posts"][0]["id"]).to eq(awesome_post.id)
      expect(data["posts"][0]["blurb"]).to include("elephant")
      expect(data["topics"][0]["id"]).to eq(awesome_post.topic_id)
    end

    it "performs the query with a type filter" do
      get "/search/query.json", params: { term: user.username, type_filter: "topic" }

      expect(response.status).to eq(200)
      data = response.parsed_body

      expect(data["posts"][0]["id"]).to eq(user_post.id)
      expect(data["users"]).to be_blank

      get "/search/query.json", params: { term: user.username, type_filter: "user" }

      expect(response.status).to eq(200)
      data = response.parsed_body

      expect(data["posts"]).to be_blank
      expect(data["users"][0]["id"]).to eq(user.id)
    end

    context "when searching by topic id" do
      it "should not be restricted by minimum search term length" do
        SiteSetting.min_search_term_length = 20_000

        get "/search/query.json",
            params: {
              term: awesome_post.topic_id,
              type_filter: "topic",
              search_for_id: true,
            }

        expect(response.status).to eq(200)
        data = response.parsed_body

        expect(data["topics"][0]["id"]).to eq(awesome_post.topic_id)
      end

      it "should return the right result" do
        get "/search/query.json",
            params: {
              term: user_post.topic_id,
              type_filter: "topic",
              search_for_id: true,
            }

        expect(response.status).to eq(200)
        data = response.parsed_body

        expect(data["topics"][0]["id"]).to eq(user_post.topic_id)
      end
    end
  end

  describe "#query" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get "/search/query.json", params: { term: "wookie" }

      expect(response.status).to eq(200)
      expect(SearchLog.where(term: "wookie")).to be_present

      json = response.parsed_body
      search_log_id = json["grouped_search_result"]["search_log_id"]
      expect(search_log_id).to be_present

      log = SearchLog.where(id: search_log_id).first
      expect(log).to be_present
      expect(log.term).to eq("wookie")
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      get "/search/query.json", params: { term: "wookie" }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: "wookie")).to be_blank
    end

    it "doesn't log when filtering by exclude_topics" do
      SiteSetting.log_search_queries = true
      get "/search/query.json", params: { term: "boop", type_filter: "exclude_topics" }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: "boop")).to be_blank
    end

    it "does not raise 500 with an empty term" do
      get "/search/query.json",
          params: {
            term: "in:first",
            type_filter: "topic",
            search_for_id: true,
          }
      expect(response.status).to eq(200)
    end

    context "when rate limited" do
      before { RateLimiter.enable }

      def unlimited_request(ip_address = "1.2.3.4")
        get "/search/query.json", params: { term: "wookie" }, env: { REMOTE_ADDR: ip_address }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["grouped_search_result"]["error"]).to eq(nil)
      end

      def limited_request(ip_address = "1.2.3.4")
        get "/search/query.json", params: { term: "wookie" }, env: { REMOTE_ADDR: ip_address }
        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["message"]).to eq(I18n.t("rate_limiter.slow_down"))
      end

      it "rate limits anon searches per user" do
        SiteSetting.rate_limit_search_anon_user_per_second = 2
        SiteSetting.rate_limit_search_anon_user_per_minute = 3

        start = Time.now
        freeze_time start

        unlimited_request
        unlimited_request
        limited_request

        freeze_time start + 2

        unlimited_request
        limited_request

        # cause it is a diff IP
        unlimited_request("100.0.0.0")
      end

      it "rate limits anon searches globally" do
        SiteSetting.rate_limit_search_anon_global_per_second = 2
        SiteSetting.rate_limit_search_anon_global_per_minute = 3

        t = Time.now
        freeze_time t

        unlimited_request("1.2.3.4")
        unlimited_request("1.2.3.5")
        limited_request("1.2.3.6")

        freeze_time t + 2

        unlimited_request("1.2.3.7")
        limited_request("1.2.3.8")
      end

      context "with a logged in user" do
        before { sign_in(user) }

        it "rate limits logged in searches" do
          SiteSetting.rate_limit_search_user = 3

          3.times do
            get "/search/query.json", params: { term: "wookie" }

            expect(response.status).to eq(200)
            json = response.parsed_body
            expect(json["grouped_search_result"]["error"]).to eq(nil)
          end

          get "/search/query.json", params: { term: "wookie" }
          expect(response.status).to eq(429)
          json = response.parsed_body
          expect(json["message"]).to eq(I18n.t("rate_limiter.slow_down"))
        end
      end
    end
  end

  describe "#show" do
    it "doesn't raise an error when search term not specified" do
      get "/search"
      expect(response.status).to eq(200)
    end

    it "raises an error when the search term length is less than required" do
      get "/search.json", params: { q: "ba" }
      expect(response.status).to eq(400)
    end

    it "raises an error when search term is a hash" do
      get "/search.json?q[foo]"
      expect(response.status).to eq(400)
    end

    it "returns a 400 error if you search for null bytes" do
      term = "hello\0hello"

      get "/search.json", params: { q: term }
      expect(response.status).to eq(400)
    end

    it "doesn't raise an error if the page is a string number" do
      get "/search.json", params: { q: "kittens", page: "3" }
      expect(response.status).to eq(200)
    end

    it "doesn't raise an error if the page is a integer number" do
      get "/search.json", params: { q: "kittens", page: 3 }
      expect(response.status).to eq(200)
    end

    it "returns a 400 error if the page parameter is invalid" do
      get "/search.json?page=xawesome%27\"</a\&"
      expect(response.status).to eq(400)
    end

    it "returns a 400 error if the page parameter is padded with spaces" do
      get "/search.json", params: { q: "kittens", page: " 3  " }
      expect(response.status).to eq(400)
    end

    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get "/search.json", params: { q: "bantha" }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: "bantha")).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      get "/search.json", params: { q: "bantha" }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: "bantha")).to be_blank
    end

    it "works when using a tag context" do
      tag = Fabricate(:tag, name: "awesome")
      awesome_topic.tags << tag
      SearchIndexer.index(awesome_topic, force: true)

      get "/search.json",
          params: {
            q: "awesome",
            context: "tag",
            context_id: "awesome",
            skip_context: false,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].length).to eq(1)
      expect(response.parsed_body["posts"][0]["id"]).to eq(awesome_post.id)
    end

    context "with restricted tags" do
      let(:restricted_tag) { Fabricate(:tag) }
      let(:admin) { Fabricate(:admin) }

      before do
        tag_group =
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [restricted_tag.name])
        awesome_topic.tags << restricted_tag
        SearchIndexer.index(awesome_topic, force: true)
      end

      it "works for user with tag group permision" do
        sign_in(admin)
        get "/search.json",
            params: {
              q: "awesome",
              context: "tag",
              context_id: restricted_tag.name,
              skip_context: false,
            }

        expect(response.status).to eq(200)
      end

      it "doesn’t work for user without tag group permission" do
        get "/search.json",
            params: {
              q: "awesome",
              context: "tag",
              context_id: restricted_tag.name,
              skip_context: false,
            }

        expect(response.status).to eq(403)
      end
    end

    context "when rate limited" do
      before { RateLimiter.enable }

      def unlimited_request(ip_address = "1.2.3.4")
        get "/search.json", params: { q: "wookie" }, env: { REMOTE_ADDR: ip_address }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["grouped_search_result"]["error"]).to eq(nil)
      end

      def limited_request(ip_address = "1.2.3.4")
        get "/search.json", params: { q: "wookie" }, env: { REMOTE_ADDR: ip_address }
        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["message"]).to eq(I18n.t("rate_limiter.slow_down"))
      end

      it "rate limits anon searches per user" do
        SiteSetting.rate_limit_search_anon_user_per_second = 2
        SiteSetting.rate_limit_search_anon_user_per_minute = 3

        t = Time.now
        freeze_time t

        unlimited_request
        unlimited_request
        limited_request

        freeze_time(t + 2)

        unlimited_request
        limited_request
        unlimited_request("1.2.3.100")
      end

      it "rate limits anon searches globally" do
        SiteSetting.rate_limit_search_anon_global_per_second = 2
        SiteSetting.rate_limit_search_anon_global_per_minute = 3

        t = Time.now
        freeze_time t

        unlimited_request("1.1.1.1")
        unlimited_request("2.2.2.2")
        limited_request("3.3.3.3")

        freeze_time(t + 2)

        unlimited_request("4.4.4.4")
        limited_request("5.5.5.5")
      end

      context "with a logged in user" do
        before { sign_in(user) }

        it "rate limits searches" do
          SiteSetting.rate_limit_search_user = 3

          3.times do
            get "/search.json", params: { q: "bantha" }

            expect(response.status).to eq(200)
            json = response.parsed_body
            expect(json["grouped_search_result"]["error"]).to eq(nil)
          end

          get "/search.json", params: { q: "bantha" }
          expect(response.status).to eq(429)
          json = response.parsed_body
          expect(json["message"]).to eq(I18n.t("rate_limiter.slow_down"))
        end
      end
    end

    context "with lazy loaded categories" do
      fab!(:parent_category) { Fabricate(:category) }
      fab!(:category) { Fabricate(:category, parent_category: parent_category) }
      fab!(:other_category) { Fabricate(:category, parent_category: parent_category) }

      fab!(:post) do
        with_search_indexer_enabled do
          topic = Fabricate(:topic, category: category)
          Fabricate(:post, topic: topic, raw: "hello world. first topic")
        end
      end

      fab!(:other_post) do
        with_search_indexer_enabled do
          topic = Fabricate(:topic, category: other_category)
          Fabricate(:post, topic: topic, raw: "hello world. second topic")
        end
      end

      before { SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

      it "returns extra categories and parent categories" do
        get "/search.json", params: { q: "hello" }

        categories = response.parsed_body["grouped_search_result"]["extra"]["categories"]
        expect(categories.map { |c| c["id"] }).to contain_exactly(
          parent_category.id,
          category.id,
          other_category.id,
        )
      end
    end
  end

  context "with search priority" do
    fab!(:very_low_priority_category) do
      Fabricate(:category, search_priority: Searchable::PRIORITIES[:very_low])
    end

    fab!(:low_priority_category) do
      Fabricate(:category, search_priority: Searchable::PRIORITIES[:low])
    end

    fab!(:high_priority_category) do
      Fabricate(:category, search_priority: Searchable::PRIORITIES[:high])
    end

    fab!(:very_high_priority_category) do
      Fabricate(:category, search_priority: Searchable::PRIORITIES[:very_high])
    end

    fab!(:very_low_priority_topic) { Fabricate(:topic, category: very_low_priority_category) }
    fab!(:low_priority_topic) { Fabricate(:topic, category: low_priority_category) }
    fab!(:high_priority_topic) { Fabricate(:topic, category: high_priority_category) }
    fab!(:very_high_priority_topic) { Fabricate(:topic, category: very_high_priority_category) }

    fab!(:very_low_priority_post) do
      with_search_indexer_enabled do
        Fabricate(:post, topic: very_low_priority_topic, raw: "This is a very Low Priority Post")
      end
    end

    fab!(:low_priority_post) do
      with_search_indexer_enabled do
        Fabricate(
          :post,
          topic: low_priority_topic,
          raw: "This is a Low Priority Post",
          created_at: 1.day.ago,
        )
      end
    end

    fab!(:high_priority_post) do
      with_search_indexer_enabled do
        Fabricate(:post, topic: high_priority_topic, raw: "This is a High Priority Post")
      end
    end

    fab!(:very_high_priority_post) do
      with_search_indexer_enabled do
        Fabricate(
          :post,
          topic: very_high_priority_topic,
          raw: "This is a Old but Very High Priority Post",
          created_at: 2.days.ago,
        )
      end
    end

    it "sort posts with search priority when search term is empty" do
      get "/search.json", params: { q: "status:open" }
      expect(response.status).to eq(200)
      data = response.parsed_body
      post1 = data["posts"].find { |e| e["id"] == very_high_priority_post.id }
      post2 = data["posts"].find { |e| e["id"] == very_low_priority_post.id }
      expect(data["posts"][0]["id"]).to eq(very_high_priority_post.id)
      expect(post1["id"]).to be > post2["id"]
    end

    it "sort posts with search priority when no order query" do
      SiteSetting.category_search_priority_high_weight = 999_999
      SiteSetting.category_search_priority_low_weight = 0

      get "/search.json", params: { q: "status:open Priority Post" }
      expect(response.status).to eq(200)
      data = response.parsed_body
      expect(data["posts"][0]["id"]).to eq(very_high_priority_post.id)
      expect(data["posts"][1]["id"]).to eq(high_priority_post.id)
      expect(data["posts"][2]["id"]).to eq(low_priority_post.id)
      expect(data["posts"][3]["id"]).to eq(very_low_priority_post.id)
    end

    it "doesn't sort posts with search priority when query with order" do
      get "/search.json", params: { q: "status:open order:latest Priority Post" }
      expect(response.status).to eq(200)
      data = response.parsed_body
      expect(data["posts"][0]["id"]).to eq(high_priority_post.id)
      expect(data["posts"][1]["id"]).to eq(very_low_priority_post.id)
      expect(data["posts"][2]["id"]).to eq(low_priority_post.id)
      expect(data["posts"][3]["id"]).to eq(very_high_priority_post.id)
    end
  end

  context "with search context" do
    it "raises an error with an invalid context type" do
      get "/search/query.json",
          params: {
            term: "test",
            search_context: {
              type: "security",
              id: "hole",
            },
          }
      expect(response.status).to eq(400)
    end

    it "raises an error with a missing id" do
      get "/search/query.json", params: { term: "test", search_context: { type: "user" } }
      expect(response.status).to eq(400)
    end

    context "with a user" do
      it "raises an error if the user can't see the context" do
        get "/search/query.json",
            params: {
              term: "test",
              search_context: {
                type: "private_messages",
                id: user.username,
              },
            }
        expect(response).to be_forbidden
      end

      it "performs the query with a search context" do
        get "/search/query.json",
            params: {
              term: "test",
              search_context: {
                type: "user",
                id: user.username,
              },
            }

        expect(response.status).to eq(200)
      end
    end

    context "with a tag" do
      it "raises an error if the tag does not exist" do
        get "/search/query.json",
            params: {
              term: "test",
              search_context: {
                type: "tag",
                id: "important-tag",
                name: "important-tag",
              },
            }
        expect(response).to be_forbidden
      end

      it "performs the query with a search context" do
        Fabricate(:tag, name: "important-tag")
        get "/search/query.json",
            params: {
              term: "test",
              search_context: {
                type: "tag",
                id: "important-tag",
                name: "important-tag",
              },
            }

        expect(response.status).to eq(200)
      end
    end
  end

  describe "#click" do
    after { SearchLog.clear_debounce_cache! }

    it "doesn't work without the necessary parameters" do
      post "/search/click.json"
      expect(response.status).to eq(400)
    end

    it "doesn't record the click for a different user" do
      sign_in(user)

      _, search_log_id =
        SearchLog.log(
          term: SecureRandom.hex,
          search_type: :header,
          user_id: -10,
          ip_address: "127.0.0.1",
        )

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: 12_345,
             search_result_type: "topic",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be_present
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for a logged in user" do
      sign_in(user)

      _, search_log_id =
        SearchLog.log(
          term: SecureRandom.hex,
          search_type: :header,
          user_id: user.id,
          ip_address: "127.0.0.1",
        )

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: 12_345,
             search_result_type: "user",
           }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(12_345)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(
        SearchLog.search_result_types[:user],
      )
    end

    it "records the click for an anonymous user" do
      get "/"
      ip_address = request.remote_ip

      _, search_log_id =
        SearchLog.log(term: SecureRandom.hex, search_type: :header, ip_address: ip_address)

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: 22_222,
             search_result_type: "topic",
           }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(22_222)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(
        SearchLog.search_result_types[:topic],
      )
    end

    it "doesn't record the click for a different IP" do
      _, search_log_id =
        SearchLog.log(term: SecureRandom.hex, search_type: :header, ip_address: "192.168.0.19")

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: 22_222,
             search_result_type: "topic",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be_present
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for search result type category" do
      get "/"
      ip_address = request.remote_ip

      _, search_log_id =
        SearchLog.log(term: SecureRandom.hex, search_type: :header, ip_address: ip_address)

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: 23_456,
             search_result_type: "category",
           }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(23_456)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(
        SearchLog.search_result_types[:category],
      )
    end

    it "records the click for search result type tag" do
      get "/"
      ip_address = request.remote_ip
      tag = Fabricate(:tag, name: "test")

      _, search_log_id =
        SearchLog.log(term: SecureRandom.hex, search_type: :header, ip_address: ip_address)

      post "/search/click.json",
           params: {
             search_log_id: search_log_id,
             search_result_id: tag.name,
             search_result_type: "tag",
           }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(tag.id)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(
        SearchLog.search_result_types[:tag],
      )
    end
  end
end
