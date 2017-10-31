require 'rails_helper'

describe OfflineController do
  it "can hit index" do
    get :index
    expect(response.status).to eq(200)
  end
end
