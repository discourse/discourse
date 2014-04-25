require 'spec_helper'

describe BadgesController do
  let!(:badge) { Fabricate(:badge) }

  context 'index' do
    it 'should return a list of all badges' do
      get :index, format: :json

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["badges"].length.should == 1
    end
  end

  context 'show' do
    it "should return a badge" do
      get :show, id: badge.id, format: :json
      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["badge"].should be_present
    end
  end
end
