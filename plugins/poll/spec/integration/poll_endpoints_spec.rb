require "rails_helper"

describe "DiscoursePoll endpoints" do
  describe "fetch voters from user_ids" do
    let(:user) { Fabricate(:user) }

    it "should return the right response" do
      get "/polls/voters.json", { user_ids: [user.id] }

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)["users"].first

      expect(json["name"]).to eq(user.name)
      expect(json["title"]).to eq(user.title)
    end
  end
end
