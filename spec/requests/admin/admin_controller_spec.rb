require 'rails_helper'

RSpec.describe Admin::AdminController do
  it "should return the right response if user isn't a staff" do
    expect do
      get "/admin", params: { api_key: 'asdiasiduga' }
    end.to raise_error(ActionController::RoutingError)
  end
end
