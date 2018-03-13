require 'rails_helper'

describe TagsController do
  before do
    SiteSetting.tagging_enabled = true
  end

  describe '#index' do

    before do
      tag = Fabricate(:tag, name: 'test')
      topic_tag = Fabricate(:tag, name: 'topic-test', topic_count: 1)
    end

    shared_examples "successfully retrieve tags with topic_count > 0" do
      it "should return the right response" do
        get "/tags.json"

        expect(response).to be_success

        tags = JSON.parse(response.body)["tags"]
        expect(tags.length).to eq(1)
        expect(tags[0]['text']).to eq("topic-test")
      end
    end

    context "with tags_listed_by_group enabled" do
      before do
        SiteSetting.tags_listed_by_group = true
      end

      include_examples "successfully retrieve tags with topic_count > 0"
    end

    context "with tags_listed_by_group disabled" do
      before do
        SiteSetting.tags_listed_by_group = false
      end

      include_examples "successfully retrieve tags with topic_count > 0"
    end
  end

  describe '#check_hashtag' do
    let(:tag) { Fabricate(:tag, name: 'test') }

    it "should return the right response" do
      get "/tags/check.json", params: { tag_values: [tag.name] }

      expect(response).to be_success

      tag = JSON.parse(response.body)["valid"].first
      expect(tag["value"]).to eq('test')
    end
  end

  describe '#personal_messages' do
    before do
      SiteSetting.allow_staff_to_tag_pms = true
      personal_message = Fabricate(:private_message_topic)
      Fabricate(:tag, topics: [personal_message], name: 'test')
    end

    context "as a normal user" do
      it "should return the right response" do
        get "/tags/personal_messages.json"

        expect(response).not_to be_success
      end
    end

    context "as an admin" do
      before do
        admin = Fabricate(:admin)
        sign_in(admin)
      end

      it "should return the right response" do
        get "/tags/personal_messages.json"

        expect(response).to be_success

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end
    end
  end
end
