# frozen_string_literal: true

RSpec.describe Admin::SearchLogsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  before do
    SearchLog.log(term: 'ruby', search_type: :header, ip_address: '127.0.0.1')
  end

  after do
    SearchLog.clear_debounce_cache!
  end

  it "is a subclass of StaffController" do
    expect(Admin::SearchLogsController < Admin::StaffController).to eq(true)
  end

  describe "#index" do
    it "raises an error if you aren't logged in" do
      get '/admin/logs/search_logs.json'
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      get '/admin/logs/search_logs.json'
      expect(response.status).to eq(404)
    end

    it "should work if you are an admin" do
      sign_in(admin)
      get '/admin/logs/search_logs.json'

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json[0]['term']).to eq('ruby')
      expect(json[0]['searches']).to eq(1)
      expect(json[0]['ctr']).to eq(0)
    end

    it "should work if you are a moderator" do
      sign_in(moderator)
      get "/admin/logs/search_logs.json"

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json[0]["term"]).to eq("ruby")
      expect(json[0]["searches"]).to eq(1)
      expect(json[0]["ctr"]).to eq(0)
    end
  end

  describe "#term" do
    it "raises an error if you aren't logged in" do
      get '/admin/logs/search_logs/term.json', params: {
        term: "ruby"
      }

      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)

      get '/admin/logs/search_logs/term.json', params: {
        term: "ruby"
      }

      expect(response.status).to eq(404)
    end

    it "should work if you are an admin" do
      sign_in(admin)

      get '/admin/logs/search_logs/term.json', params: {
        term: "ruby"
      }

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json['term']['type']).to eq('search_log_term')
      expect(json['term']['search_result']).to be_present
    end

    it "should work if you are a moderator" do
      sign_in(moderator)

      get "/admin/logs/search_logs/term.json", params: {
        term: "ruby"
      }

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["term"]["type"]).to eq("search_log_term")
      expect(json["term"]["search_result"]).to be_present
    end
  end
end
