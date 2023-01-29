# frozen_string_literal: true

RSpec.describe OfflineController do
  it "can hit index" do
    get "/offline.html"
    expect(response.status).to eq(200)
  end
end
