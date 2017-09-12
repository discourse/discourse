require 'rails_helper'

RSpec.describe Admin::FlaggedTopicsController do
  let(:admin) { Fabricate(:admin) }
  let!(:flag) { Fabricate(:flag) }

  before do
    sign_in(admin)
  end

  it "returns a list of flagged topics" do
    get "/admin/flagged_topics.json"
    expect(response).to be_success

    data = ::JSON.parse(response.body)
    expect(data['flagged_topics']).to be_present
    expect(data['users']).to be_present
  end
end
