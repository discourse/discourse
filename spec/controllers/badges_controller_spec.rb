require 'spec_helper'

describe BadgesController do
  let!(:badge) { Fabricate(:badge) }

  context 'index' do
    it 'should return a list of all badges' do
      xhr :get, :index

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["badges"].length.should == 1
    end
  end
end
