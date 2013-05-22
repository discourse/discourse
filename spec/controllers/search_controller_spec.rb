require 'spec_helper'

describe SearchController do

  it 'performs the query' do
    guardian = Guardian.new
    Guardian.stubs(:new).returns(guardian)

    search = mock()
    Search.expects(:new).with('test', guardian: guardian, type_filter: nil).returns(search)
    search.expects(:execute)

    xhr :get, :query, term: 'test'
  end

  it 'performs the query with a filter' do
    guardian = Guardian.new
    Guardian.stubs(:new).returns(guardian)

    search = mock()
    Search.expects(:new).with('test', guardian: guardian, type_filter: 'topic').returns(search)
    search.expects(:execute)

    xhr :get, :query, term: 'test', type_filter: 'topic'
  end

end
