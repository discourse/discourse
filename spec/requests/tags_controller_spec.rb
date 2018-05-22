require 'rails_helper'

describe TagsController do
  before do
    SiteSetting.tagging_enabled = true
  end

  describe '#index' do

    before do
      Fabricate(:tag, name: 'test')
      Fabricate(:tag, name: 'topic-test', topic_count: 1)
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
      before { SiteSetting.tags_listed_by_group = true }
      include_examples "successfully retrieve tags with topic_count > 0"
    end

    context "with tags_listed_by_group disabled" do
      before { SiteSetting.tags_listed_by_group = false }
      include_examples "successfully retrieve tags with topic_count > 0"
    end

    context "when user can admin tags" do

      it "succesfully retrieve all tags" do
        sign_in(Fabricate(:admin))

        get "/tags.json"

        expect(response).to be_success

        tags = JSON.parse(response.body)["tags"]
        expect(tags.length).to eq(2)
      end

    end
  end

  describe '#show' do
    before do
      Fabricate(:tag, name: 'test')
    end

    it "should return the right response" do
      get "/tags/test"
      expect(response).to be_success
    end

    it "should handle invalid tags" do
      get "/tags/%2ftest%2f"
      expect(response.status).to eq(404)
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

  describe "#update" do
    let(:tag) { Fabricate(:tag) }
    let(:admin) { Fabricate(:admin) }

    before do
      tag
      sign_in(admin)
    end

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events {
        put "/tags/#{tag.name}.json", params: {
          tag: {
            id: 'hello'
          }
        }
      }.last

      expect(event[:event_name]).to eq(:tag_updated)
      expect(event[:params].first).to eq(tag)
    end
  end

  describe '#personal_messages' do
    let(:regular_user) { Fabricate(:trust_level_4) }
    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }
    let(:personal_message) do
      Fabricate(:private_message_topic, user: regular_user, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: regular_user),
        Fabricate.build(:topic_allowed_user, user: moderator),
        Fabricate.build(:topic_allowed_user, user: admin)
      ])
    end

    before do
      SiteSetting.allow_staff_to_tag_pms = true
      Fabricate(:tag, topics: [personal_message], name: 'test')
    end

    context "as a regular user" do
      it "can't see pm tags" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response).not_to be_success
      end
    end

    context "as an moderator" do
      before do
        sign_in(moderator)
      end

      it "can't see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response).not_to be_success
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{moderator.username}.json"

        expect(response).to be_success

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end
    end

    context "as an admin" do
      before do
        sign_in(admin)
      end

      it "can see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response).to be_success

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{admin.username}.json"

        expect(response).to be_success

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end
    end
  end
end
