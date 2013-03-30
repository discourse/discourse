require 'spec_helper'

describe SearchController do

  it 'performs the query' do
    Search.expects(:query).with('test', nil, 3)
    xhr :get, :query, term: 'test'
  end

  it 'performs the query with a filter' do
    Search.expects(:query).with('test', 'topic', 3)
    xhr :get, :query, term: 'test', type_filter: 'topic'
  end

  it 'is empty without querying when the user is not logged in and site_requires_login is set' do
    SiteSetting.stubs(:site_requires_login?).returns(true)
    Search.expects(:query).never
    xhr :get, :query, term: 'foo bar'
    ActiveSupport::JSON.decode(response.body).should == []
  end

end
