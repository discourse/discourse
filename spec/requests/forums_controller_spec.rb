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

end
