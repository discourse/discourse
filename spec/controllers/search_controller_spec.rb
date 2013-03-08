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

end
