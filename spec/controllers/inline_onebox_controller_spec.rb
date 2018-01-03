require 'rails_helper'

describe InlineOneboxController do

  it "requires the user to be logged in" do
    expect do
      get :show, params: { urls: [] }, format: :json
    end.to raise_error(Discourse::NotLoggedIn)
  end

  context "logged in" do
    let!(:user) { log_in(:user) }

    it "returns empty JSON for empty input" do
      get :show, params: { urls: [] }, format: :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['inline-oneboxes']).to eq([])
    end

    context "topic link" do
      let(:topic) { Fabricate(:topic) }

      it "returns information for a valid link" do
        get :show, params: { urls: [ topic.url ] }, format: :json
        expect(response).to be_success
        json = JSON.parse(response.body)
        onebox = json['inline-oneboxes'][0]

        expect(onebox).to be_present
        expect(onebox['url']).to eq(topic.url)
        expect(onebox['title']).to eq(topic.title)
      end
    end

  end

end
