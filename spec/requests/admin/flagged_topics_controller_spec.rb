require 'rails_helper'

RSpec.describe Admin::FlaggedTopicsController do
  let!(:flag) { Fabricate(:flag) }

  shared_examples "successfully retrieve list of flagged topics" do
    it "returns a list of flagged topics" do
      get "/admin/flagged_topics.json"
      expect(response.status).to eq(200)

      data = ::JSON.parse(response.body)
      expect(data['flagged_topics']).to be_present
      expect(data['users']).to be_present
    end
  end

  context "as admin" do
    before do
      sign_in(Fabricate(:admin))
    end

    include_examples "successfully retrieve list of flagged topics"
  end

  context "as moderator" do
    before do
      sign_in(Fabricate(:moderator))
    end

    include_examples "successfully retrieve list of flagged topics"
  end

end
