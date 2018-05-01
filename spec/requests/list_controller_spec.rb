require 'rails_helper'

RSpec.describe ListController do
  let(:topic) { Fabricate(:topic) }
  let(:group) { Fabricate(:group) }

  describe '#index' do
    it "doesn't throw an error with a negative page" do
      get "/#{Discourse.anonymous_filters[1]}", params: { page: -1024 }
      expect(response).to be_success
    end

    it "doesn't throw an error with page params as an array" do
      get "/#{Discourse.anonymous_filters[1]}", params: { page: ['7'] }
      expect(response).to be_success
    end
  end

  describe "categories and X" do
    it "returns top topics" do
      Fabricate(:topic, like_count: 1000, posts_count: 100)
      TopTopic.refresh!

      get "/categories_and_top.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(1)

      get "/categories_and_latest.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(1)
    end
  end

  describe 'suppress from latest' do

    it 'supresses categories' do
      topic

      get "/latest.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(1)

      get "/categories_and_latest.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(1)

      topic.category.suppress_from_latest = true
      topic.category.save

      get "/latest.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(0)

      get "/categories_and_latest.json"
      data = JSON.parse(response.body)
      expect(data["topic_list"]["topics"].length).to eq(0)
    end

  end

  describe 'titles for crawler layout' do
    it 'has no title for the default URL' do
      topic
      filter = Discourse.anonymous_filters[0]
      get "/#{filter}", params: { _escaped_fragment_: 'true' }

      expect(response.body).to include(I18n.t("rss_description.posts"))

      expect(response.body).to_not include(
        I18n.t('js.filters.with_topics', filter: filter)
      )
    end

    it 'has a title for non-default URLs' do
      topic
      filter = Discourse.anonymous_filters[1]
      get "/#{filter}", params: { _escaped_fragment_: 'true' }

      expect(response.body).to include(
        I18n.t('js.filters.with_topics', filter: filter)
      )
    end
  end

  describe "filter private messages by tag" do
    let(:user) { Fabricate(:user) }
    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }
    let(:tag) { Fabricate(:tag) }
    let(:private_message) { Fabricate(:private_message_topic) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.allow_staff_to_tag_pms = true
      Fabricate(:topic_tag, tag: tag, topic: private_message)
    end

    it 'should fail for non-staff users' do
      sign_in(user)
      get "/topics/private-messages-tags/#{user.username}/#{tag.name}.json"
      expect(response.status).to eq(404)
    end

    it 'should be success for staff users' do
      [moderator, admin].each do |user|
        sign_in(user)
        get "/topics/private-messages-tags/#{user.username}/#{tag.name}.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#private_messages_group' do
    let(:user) do
      user = Fabricate(:user)
      group.add(user)
      sign_in(user)
      user
    end

    let!(:topic) do
      Fabricate(:private_message_topic,
        allowed_groups: [group],
      )
    end

    let(:private_post) { Fabricate(:post, topic: topic) }

    it 'should return the right response' do
      get "/topics/private-messages-group/#{user.username}/#{group.name}.json"

      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)["topic_list"]["topics"].first["id"])
        .to eq(topic.id)
    end
  end

  describe '#group_topics' do
    %i{user user2}.each do |user|
      let(user) do
        user = Fabricate(:user)
        group.add(user)
        user
      end
    end

    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:topic2) { Fabricate(:topic, user: user2) }
    let!(:another_topic) { Fabricate(:topic) }

    describe 'when an invalid group name is given' do
      it 'should return the right response' do
        get "/topics/groups/something.json"

        expect(response.status).to eq(404)
      end
    end

    describe 'for an anon user' do
      describe 'public visible group' do
        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["topic_list"]).to be_present
        end
      end

      describe 'restricted group' do
        before { group.update!(visibility_level: Group.visibility_levels[:staff]) }

        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(403)
        end
      end
    end

    describe 'for a normal user' do
      before { sign_in(Fabricate(:user)) }

      describe 'restricted group' do
        before { group.update!(visibility_level: Group.visibility_levels[:staff]) }

        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(403)
        end
      end
    end

    describe 'for a group user' do
      before do
        sign_in(user)
      end

      it 'should be able to view the topics started by group users' do
        get "/topics/groups/#{group.name}.json"

        expect(response.status).to eq(200)

        topics = JSON.parse(response.body)["topic_list"]["topics"]

        expect(topics.map { |topic| topic["id"] }).to contain_exactly(
          topic.id, topic2.id
        )
      end
    end
  end
end
