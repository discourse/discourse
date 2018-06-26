require 'rails_helper'

RSpec.describe Admin::AdminController do
  describe '#index' do
    it "needs you to be logged in" do
      get "/admin.json"
      expect(response.status).to eq(404)
    end

    it "should return the right response if user isn't a staff" do
      sign_in(Fabricate(:user))
      get "/admin", params: { api_key: 'asdiasiduga' }
      expect(response.status).to eq(404)

      get "/admin"
      expect(response.status).to eq(404)
    end
  end
end
