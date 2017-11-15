require 'rails_helper'

RSpec.describe Admin::SearchLogsController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  before do
    SearchLog.log(term: 'ruby', search_type: :header, ip_address: '127.0.0.1')
  end

  context "#index" do
    it "raises an error if you aren't logged in" do
      expect do
        get '/admin/logs/search_logs.json'
      end.to raise_error(ActionController::RoutingError)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      expect do
        get '/admin/logs/search_logs.json'
      end.to raise_error(ActionController::RoutingError)
    end

    it "should work if you are an admin" do
      sign_in(admin)
      get '/admin/logs/search_logs.json'

      expect(response).to be_success

      json = ::JSON.parse(response.body)
      expect(json[0]['term']).to eq('ruby')
    end
  end
end
