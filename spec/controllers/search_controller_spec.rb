require 'rails_helper'

describe SearchController do

  context "integration" do
    before do
      SearchIndexer.enable
    end

    it "can search correctly" do
      my_post = Fabricate(:post, raw: 'this is my really awesome post')

      get :query, params: {
        term: 'awesome', include_blurb: true
      }, format: :json

      expect(response).to be_success
      data = JSON.parse(response.body)
      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['posts'][0]['blurb']).to eq('this is my really awesome post')
      expect(data['topics'][0]['id']).to eq(my_post.topic_id)
    end

    it 'performs the query with a type filter' do
      user = Fabricate(:user)
      my_post = Fabricate(:post, raw: "#{user.username} is a cool person")

      get :query, params: {
        term: user.username, type_filter: 'topic'
      }, format: :json

      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['users']).to be_blank

      get :query, params: {
        term: user.username, type_filter: 'user'
      }, format: :json

      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts']).to be_blank
      expect(data['users'][0]['id']).to eq(user.id)
    end

    context 'searching by topic id' do
      it 'should not be restricted by minimum search term length' do
        SiteSetting.min_search_term_length = 20000

        post = Fabricate(:post)

        get :query, params: {
          term: post.topic_id,
          type_filter: 'topic',
          search_for_id: true
        }, format: :json

        expect(response).to be_success
        data = JSON.parse(response.body)

        expect(data['topics'][0]['id']).to eq(post.topic_id)
      end

      it "should return the right result" do
        user = Fabricate(:user)
        my_post = Fabricate(:post, raw: "#{user.username} is a cool person")

        get :query, params: {
          term: my_post.topic_id,
          type_filter: 'topic',
          search_for_id: true
        }, format: :json

        expect(response).to be_success
        data = JSON.parse(response.body)

        expect(data['topics'][0]['id']).to eq(my_post.topic_id)
      end
    end
  end

  context "#query" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get :query, params: { term: 'wookie' }, format: :json

      expect(response).to be_success
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
      get :query, params: { term: 'wookie' }, format: :json
      expect(response).to be_success
      expect(SearchLog.where(term: 'wookie')).to be_blank
    end
  end

  context "#show" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      get :show, params: { q: 'bantha' }, format: :json
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      get :show, params: { q: 'bantha' }, format: :json
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_blank
    end
  end

  context "search context" do
    it "raises an error with an invalid context type" do
      get :query, params: {
        term: 'test', search_context: { type: 'security', id: 'hole' }
      }, format: :json
      expect(response.status).to eq(400)
    end

    it "raises an error with a missing id" do
      get :query,
        params: { term: 'test', search_context: { type: 'user' } },
        format: :json
      expect(response.status).to eq(400)
    end

    context "with a user" do
      let(:user) { Fabricate(:user) }

      it "raises an error if the user can't see the context" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        get :query, params: {
          term: 'test', search_context: { type: 'user', id: user.username }
        }, format: :json
        expect(response).not_to be_success
      end

      it 'performs the query with a search context' do
        get :query, params: {
          term: 'test', search_context: { type: 'user', id: user.username }
        }, format: :json

        expect(response).to be_success
      end
    end

  end

  context "#click" do
    before do
      SearchLog.clear_debounce_cache!
    end

    it "doesn't work wthout the necessary parameters" do
      expect do
        post :click, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    it "doesn't record the click for a different user" do
      log_in(:user)

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        user_id: -10,
        ip_address: '127.0.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'topic'
      }

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for a logged in user" do
      user = log_in(:user)

      _, search_log_id = SearchLog.log(
        term: 'foobar',
        search_type: :header,
        user_id: user.id,
        ip_address: '127.0.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'user'
      }, format: :json

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to eq(12345)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:user])
    end

    it "records the click for an anonymous user" do
      request.remote_addr = '192.168.0.1';

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }, format: :json

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to eq(22222)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:topic])
    end

    it "doesn't record the click for a different IP" do
      request.stubs(:remote_ip).returns('192.168.0.2')

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to be_blank
    end

    it "records the click for search result type category" do
      request.remote_addr = '192.168.0.1';

      _, search_log_id = SearchLog.log(
        term: 'dev',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: 23456,
        search_result_type: 'category'
      }, format: :json

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to eq(23456)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:category])
    end

    it "records the click for search result type tag" do
      request.remote_addr = '192.168.0.1';
       tag = Fabricate(:tag, name: 'test')

      _, search_log_id = SearchLog.log(
        term: 'test',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      post :click, params: {
        search_log_id: search_log_id,
        search_result_id: tag.name,
        search_result_type: 'tag'
      }, format: :json

      expect(response).to be_success
      expect(SearchLog.find(search_log_id).search_result_id).to eq(tag.id)
      expect(SearchLog.find(search_log_id).search_result_type).to eq(SearchLog.search_result_types[:tag])
    end
  end
end
