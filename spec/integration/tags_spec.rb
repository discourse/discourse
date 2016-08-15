require 'rails_helper'

describe "Tags" do
  before do
    SiteSetting.tagging_enabled = true
  end

  describe "checking tag hashtags" do
    let(:tag) { Fabricate(:tag, name: 'test') }

    it "should return the right response" do
      get "/tags/check.json", { tag_values: [tag.name] }

      expect(response).to be_success

      tag = JSON.parse(response.body)["valid"].first
      expect(tag["value"]).to eq('test')
    end
  end
end
