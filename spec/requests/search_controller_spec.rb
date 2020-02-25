# frozen_string_literal: true

require 'rails_helper'

describe SearchController do

  fab!(:awesome_post) do
    SearchIndexer.enable
    Fabricate(:post, raw: 'this is my really awesome post')
  end

  fab!(:user) do
    Fabricate(:user)
  end

  fab!(:user_post) do
    SearchIndexer.enable
    Fabricate(:post, raw: "#{user.username} is a cool person")
  end

  context "integration" do
    before do
      SearchIndexer.enable
    end

    before do
      # TODO be a bit more strategic here instead of junking
      # all of redis
      Discourse.redis.flushall
    end

    after do
      Discourse.redis.flushall
    end

    context "when overloaded" do

      before do
        global_setting :disable_search_queue_threshold, 0.2
      end

      let! :start_time do
        freeze_time
        Time.now
      end

      let! :current_time do
        freeze_time 0.3.seconds.from_now
      end

      it "errors on #query" do

        get "/search/query.json", headers: {
          "HTTP_X_REQUEST_START" => "t=#{start_time.to_f}"
        }, params: {
          term: "hi there", include_blurb: true
        }

        expect(response.status).to eq(409)
      end

      it "no results and error on #index" do
        get "/search.json", headers: {
          "HTTP_X_REQUEST_START" => "t=#{start_time.to_f}"
        }, params: {
          q: "awesome"
        }

        expect(response.status).to eq(200)

        data = JSON.parse(response.body)

        expect(data["posts"]).to be_empty
        expect(data["grouped_search_result"]["error"]).not_to be_empty
      end

    end

    it "returns a 400 error if you search for null bytes" do
      term = "hello\0hello"

      get "/search/query.json", params: {
        term: term, include_blurb: true
      }

      expect(response.status).to eq(400)
    end

    it "can search correctly" do
      get "/search/query.json", params: {
        term: 'awesome', include_blurb: true
      }

      expect(response.status).to eq(200)

      data = JSON.parse(response.body)

      expect(data['posts'].length).to eq(1)
      expect(data['posts'][0]['id']).to eq(awesome_post.id)
      expect(data['posts'][0]['blurb']).to eq(awesome_post.raw)
      expect(data['topics'][0]['id']).to eq(awesome_post.topic_id)
    end

    it 'performs the query with a type filter' do

      get "/search/query.json", params: {
        term: user.username, type_filter: 'topic'
      }

      expect(response.status).to eq(200)
      data = JSON.parse(response.body)

      expect(data['posts'][0]['id']).to eq(user_post.id)
      expect(data['users']).to be_blank

      get "/search/query.json", params: {
        term: user.username, type_filter: 'user'
      }

      expect(response.status).to eq(200)
      data = JSON.parse(response.body)

      expect(data['posts']).to be_blank
      expect(data['users'][0]['id']).to eq(user.id)
    end

    context 'searching by topic id' do
      it 'should not be restricted by minimum search term length' do
        SiteSetting.min_search_term_length = 20000

        get "/search/query.json", params: {
          term: awesome_post.topic_id,
          type_filter: 'topic',
          search_for_id: true
        }

        expect(response.status).to eq(200)
        data = JSON.parse(response.body)

        expect(data['topics'][0]['id']).to eq(awesome_post.topic_id)
      end

      it "should return the right result" do

        get "/search/query.json", params: {
          term: user_post.topic_id,
          type_filter: 'topic',
          search_for_id: true
        }

        expect(response.status).to eq(200)
        data = JSON.parse(response.body)

        expect(data['topics'][0]['id']).to eq(user_post.topic_id)
      end
    end
  end

  context "#query" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get "/search/query.json", params: { term: 'wookie' }

      expect(response.status).to eq(200)
      expect(SearchLog.where(term: 'wookie')).to be_present

      json = JSON.parse(response.body)
      search_log_id = json['grouped_search_result']['search_log_id']
      expect(search_log_id).to be_present

      log = SearchLog.where(id: search_log_id).first
      expect(log).to be_present
      expect(log.term).to eq('wookie')
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      get "/search/query.json", params: { term: 'wookie' }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: 'wookie')).to be_blank
    end
  end

  context "#show" do
    it "doesn't raise an error when search term not specified" do
      get "/search"
      expect(response.status).to eq(200)
    end

    it "raises an error when the search term length is less than required" do
      get "/search.json", params: { q: 'ba' }
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

    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get "/search.json", params: { q: 'bantha' }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: 'bantha')).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      get "/search.json", params: { q: 'bantha' }
      expect(response.status).to eq(200)
      expect(SearchLog.where(term: 'bantha')).to be_blank
    end
  end

  context "search context" do
    it "raises an error with an invalid context type" do
      get "/search/query.json", params: {
        term: 'test', search_context: { type: 'security', id: 'hole' }
      }
      expect(response.status).to eq(400)
    end

    it "raises an error with a missing id" do
      get "/search/query.json",
        params: { term: 'test', search_context: { type: 'user' } }
      expect(response.status).to eq(400)
    end

    context "with a user" do

      it "raises an error if the user can't see the context" do
        get "/search/query.json", params: {
          term: 'test', search_context: { type: 'private_messages', id: user.username }
        }
        expect(response).to be_forbidden
      end

      it 'performs the query with a search context' do
        get "/search/query.json", params: {
          term: 'test', search_context: { type: 'user', id: user.username }
        }

        expect(response.status).to eq(200)
      end
    end

    context "with a tag" do
      it "raises an error if the tag does not exist" do
        get "/search/query.json", params: {
          term: 'test', search_context: { type: 'tag', id: 'important-tag', name: 'important-tag' }
        }
        expect(response).to be_forbidden
      end

      it 'performs the query with a search context' do
        Fabricate(:tag, name: 'important-tag')
        get "/search/query.json", params: {
          term: 'test', search_context: { type: 'tag', id: 'important-tag', name: 'important-tag' }
        }

        expect(response.status).to eq(200)
      end
    end
  end

  context "#click" do
    after do
      SearchLog.clear_debounce_cache!
    end

    it "doesn't work wthout the necessary parameters" do
      post "/search/click.json"
      expect(response.status).to eq(400)
    end

    it "doesn't record the click for a different user" do
      sign_in(user)

      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        user_id: -10,
        ip_address: '127.0.0.1'
      )

      post "/search/click", params: {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'topic'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for a logged in user" do
      sign_in(user)

      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        user_id: user.id,
        ip_address: '127.0.0.1'
      )

      post "/search/click.json", params: {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'user'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(12345)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:user])
    end

    it "records the click for an anonymous user" do
      get "/"
      ip_address = request.remote_ip

      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        ip_address: ip_address
      )

      post "/search/click.json", params: {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(22222)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:topic])
    end

    it "doesn't record the click for a different IP" do
      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        ip_address: '192.168.0.19'
      )

      post "/search/click", params: {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for search result type category" do
      get "/"
      ip_address = request.remote_ip

      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        ip_address: ip_address
      )

      post "/search/click.json", params: {
        search_log_id: search_log_id,
        search_result_id: 23456,
        search_result_type: 'category'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(23456)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:category])
    end

    it "records the click for search result type tag" do
      get "/"
      ip_address = request.remote_ip
      tag = Fabricate(:tag, name: 'test')

      _, search_log_id = SearchLog.log(
        term: SecureRandom.hex,
        search_type: :header,
        ip_address: ip_address
      )

      post "/search/click.json", params: {
        search_log_id: search_log_id,
        search_result_id: tag.name,
        search_result_type: 'tag'
      }

      expect(response.status).to eq(200)
      expect(SearchLog.find(search_log_id).search_result_id).to eq(tag.id)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:tag])
    end
  end
end
