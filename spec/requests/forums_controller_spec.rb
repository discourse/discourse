# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForumsController do

  describe "read only header" do
    it "returns no read only header by default" do
      get "/srv/status"
      expect(response.status).to eq(200)
      expect(response.headers['Discourse-Readonly']).to eq(nil)
    end

    it "returns a readonly header if the site is read only" do
      Discourse.received_postgres_readonly!
      get "/srv/status"
      expect(response.status).to eq(200)
      expect(response.headers['Discourse-Readonly']).to eq('true')
    end
  end

  describe "during shutdown" do
    before(:each) do
      $shutdown = true
    end
    after(:each) do
      $shutdown = nil
    end

    it "returns a 500 response" do
      get "/srv/status"
      expect(response.status).to eq(500)
    end
    it "returns a 200 response when given shutdown_ok" do
      get "/srv/status?shutdown_ok=1"
      expect(response.status).to eq(200)
    end
  end

end
