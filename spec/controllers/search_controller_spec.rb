require 'rails_helper'

describe SearchController do

  context "integration" do
    before do
      SearchIndexer.enable
    end

    it "can search correctly" do
      my_post = Fabricate(:post, raw: 'this is my really awesome post')
      xhr :get, :query, term: 'awesome', include_blurb: true

      expect(response).to be_success
      data = JSON.parse(response.body)
      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['posts'][0]['blurb']).to eq('this is my really awesome post')
      expect(data['topics'][0]['id']).to eq(my_post.topic_id)
    end

    it 'performs the query with a type filter' do
      user = Fabricate(:user)
      my_post = Fabricate(:post, raw: "#{user.username} is a cool person")
      xhr :get, :query, term: user.username, type_filter: 'topic'

      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['users']).to be_blank

      xhr :get, :query, term: user.username, type_filter: 'user'
      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts']).to be_blank
      expect(data['users'][0]['id']).to eq(user.id)
    end

    it "can search for id" do
      user = Fabricate(:user)
      my_post = Fabricate(:post, raw: "#{user.username} is a cool person")
      xhr(
        :get,
        :query,
        term: my_post.topic_id,
        type_filter: 'topic',
        search_for_id: true
      )
      expect(response).to be_success
      data = JSON.parse(response.body)
      expect(data['topics'][0]['id']).to eq(my_post.topic_id)
    end
  end

  context "#query" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      xhr :get, :query, term: 'wookie'

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
      xhr :get, :query, term: 'wookie'
      expect(response).to be_success
      expect(SearchLog.where(term: 'wookie')).to be_blank
    end
  end

  context "#show" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      xhr :get, :show, q: 'bantha'
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      xhr :get, :show, q: 'bantha'
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_blank
    end
  end

  context "search context" do
    it "raises an error with an invalid context type" do
      expect {
        xhr :get, :query, term: 'test', search_context: {type: 'security', id: 'hole'}
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error with a missing id" do
      expect {
        xhr :get, :query, term: 'test', search_context: {type: 'user'}
      }.to raise_error(Discourse::InvalidParameters)
    end

    context "with a user" do
      let(:user) { Fabricate(:user) }
      it "raises an error if the user can't see the context" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
        expect(response).not_to be_success
      end

      it 'performs the query with a search context' do
        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
        expect(response).to be_success
      end
    end

  end

  context "#click" do
    it "doesn't work wthout the necessary parameters" do
      expect(-> {
        xhr :post, :click
      }).to raise_error(ActionController::ParameterMissing)
    end

    it "doesn't record the click for a different user" do
      log_in(:user)

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        user_id: -10,
        ip_address: '127.0.0.1'
      )

      xhr :post, :click, {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'topic'
      }
      expect(response).to be_success

      expect(SearchLog.find(search_log_id).clicked_topic_id).to be_blank
    end

    it "records the click for a logged in user" do
      user = log_in(:user)

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        user_id: user.id,
        ip_address: '127.0.0.1'
      )

      xhr :post, :click, {
        search_log_id: search_log_id,
        search_result_id: 12345,
        search_result_type: 'topic'
      }
      expect(response).to be_success

      expect(SearchLog.find(search_log_id).clicked_topic_id).to eq(12345)
    end

    it "records the click for an anonymous user" do
      request.stubs(:remote_ip).returns('192.168.0.1')

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      xhr :post, :click, {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }
      expect(response).to be_success

      expect(SearchLog.find(search_log_id).clicked_topic_id).to eq(22222)
    end

    it "doesn't record the click for a different IP" do
      request.stubs(:remote_ip).returns('192.168.0.2')

      _, search_log_id = SearchLog.log(
        term: 'kitty',
        search_type: :header,
        ip_address: '192.168.0.1'
      )

      xhr :post, :click, {
        search_log_id: search_log_id,
        search_result_id: 22222,
        search_result_type: 'topic'
      }
      expect(response).to be_success

      expect(SearchLog.find(search_log_id).clicked_topic_id).to be_blank
    end
  end
end
