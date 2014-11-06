require 'spec_helper'

describe SearchController do

  context "integration" do

    before do
      ActiveRecord::Base.observers.enable :search_observer
    end

    it "can search correctly" do
      my_post = Fabricate(:post, raw: 'this is my really awesome post')
      xhr :get, :query, term: 'awesome', include_blurb: true

      response.should be_success
      data = JSON.parse(response.body)
      data['posts'][0]['id'].should == my_post.id
      data['posts'][0]['blurb'].should == 'this is my really awesome post'
      data['topics'][0]['id'].should == my_post.topic_id
    end
  end


  let(:search_context) { {type: 'user', id: 'eviltrout'} }

  context "basics" do
    let(:guardian) { Guardian.new }
    let(:search) { mock() }

    before do
      Guardian.stubs(:new).returns(guardian)
    end

    it 'performs the query' do
      Search.expects(:new).with('test', guardian: guardian).returns(search)
      search.expects(:execute)

      xhr :get, :query, term: 'test'
    end

    it 'performs the query with a filter' do
      Search.expects(:new).with('test', guardian: guardian, type_filter: 'topic').returns(search)
      search.expects(:execute)

      xhr :get, :query, term: 'test', type_filter: 'topic'
    end

    it "performs the query and returns results including blurbs" do
      Search.expects(:new).with('test', guardian: guardian, include_blurbs: true).returns(search)
      search.expects(:execute)

      xhr :get, :query, term: 'test', include_blurbs: 'true'
    end

    it 'performs the query with a filter and passes through search_for_id' do
      Search.expects(:new).with('test', guardian: guardian, search_for_id: true, type_filter: 'topic').returns(search)
      search.expects(:execute)

      xhr :get, :query, term: 'test', type_filter: 'topic', search_for_id: true
    end
  end


  context "search context" do

    it "raises an error with an invalid context type" do
      lambda {
        xhr :get, :query, term: 'test', search_context: {type: 'security', id: 'hole'}
      }.should raise_error(Discourse::InvalidParameters)
    end

    it "raises an error with a missing id" do
      lambda {
        xhr :get, :query, term: 'test', search_context: {type: 'user'}
      }.should raise_error(Discourse::InvalidParameters)
    end

    context "with a user" do

      let(:user) { Fabricate(:user) }

      it "raises an error if the user can't see the context" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
        response.should_not be_success
      end


      it 'performs the query with a search context' do
        guardian = Guardian.new
        Guardian.stubs(:new).returns(guardian)

        search = mock()
        Search.expects(:new).with('test', guardian: guardian, search_context: user).returns(search)
        search.expects(:execute)

        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
      end

    end


  end



end
