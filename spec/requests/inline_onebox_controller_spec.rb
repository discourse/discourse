require 'rails_helper'

describe InlineOneboxController do

  it "requires the user to be logged in" do
    get "/inline-onebox.json", params: { urls: [] }
    expect(response.status).to eq(403)
  end

  context "logged in" do
    let!(:user) { sign_in(Fabricate(:user)) }

    it "returns empty JSON for empty input" do
      get "/inline-onebox.json", params: { urls: [] }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json['inline-oneboxes']).to eq([])
    end

    context "topic link" do
      let(:topic) { Fabricate(:topic) }

      it "returns information for a valid link" do
        get "/inline-onebox.json", params: { urls: [ topic.url ] }
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        onebox = json['inline-oneboxes'][0]

        expect(onebox).to be_present
        expect(onebox['url']).to eq(topic.url)
        expect(onebox['title']).to eq(topic.title)
      end
    end
  end
end
