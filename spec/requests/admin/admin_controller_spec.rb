require 'rails_helper'

RSpec.describe Admin::AdminController do
  it "should return the right response if user isn't a staff" do
    get "/admin", params: { api_key: 'asdiasiduga' }
    expect(response.status).to eq(404)

    get "/admin"
    expect(response.status).to eq(404)
  end
end
