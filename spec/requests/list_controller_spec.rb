require 'rails_helper'

RSpec.describe ListController do
  let(:topic) { Fabricate(:topic, user: user) }
  let(:group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user) }

  before do
    SiteSetting.top_menu = 'latest|new|unread|categories'
  end

  describe '#index' do
    it "doesn't throw an error with a negative page" do
      get "/#{Discourse.anonymous_filters[1]}", params: { page: -1024 }
      expect(response.status).to eq(200)
    end

    it "doesn't throw an error with page params as an array" do
      get "/#{Discourse.anonymous_filters[1]}", params: { page: ['7'] }
      expect(response.status).to eq(200)
    end

    (Discourse.anonymous_filters - [:categories]).each do |filter|
      context "#{filter}" do
        it "succeeds" do
          get "/#{filter}"
          expect(response.status).to eq(200)
        end
      end
    end

    it 'allows users to filter on a set of topic ids' do
      p = create_post

      get "/latest.json", params: { topic_ids: "#{p.topic_id}" }
      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["topic_list"]["topics"].length).to eq(1)
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

  describe 'RSS feeds' do
    it 'renders latest RSS' do
      get "/latest.rss"
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders top RSS' do
      get "/top.rss"
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('application/rss+xml')
    end

    TopTopic.periods.each do |period|
      it "renders #{period} top RSS" do
        get "/top/#{period}.rss"
        expect(response.status).to eq(200)
        expect(response.content_type).to eq('application/rss+xml')
      end
    end
  end

  describe 'category' do
    context 'in a category' do
      let(:category) { Fabricate(:category) }
      let(:group) { Fabricate(:group) }
      let(:private_category) { Fabricate(:private_category, group: group) }

      context 'without access to see the category' do
        it "responds with a 404 error" do
          get "/c/#{private_category.slug}/l/latest"
          expect(response.status).to eq(404)
        end
      end

      context 'with access to see the category' do
        it "succeeds" do
          get "/c/#{category.slug}/l/latest"
          expect(response.status).to eq(200)
        end
      end

      context 'with a link that includes an id' do
        it "succeeds" do
          get "/c/#{category.id}-#{category.slug}/l/latest"
          expect(response.status).to eq(200)
        end
      end

      context 'with a link that has a parent slug, slug and id in its path' do
        let(:child_category) { Fabricate(:category, parent_category: category) }

        context "with valid slug" do
          it "redirects to the child category" do
            get "/c/#{category.slug}/#{child_category.slug}/l/latest", params: {
              id: child_category.id
            }
            expect(response).to redirect_to(child_category.url)
          end
        end

        context "with invalid slug" do
          it "redirects to child category" do
            get "/c/random_slug/another_random_slug/l/latest", params: {
              id: child_category.id
            }
            expect(response).to redirect_to(child_category.url)
          end
        end
      end

      context 'another category exists with a number at the beginning of its name' do
        # One category has another category's id at the beginning of its name
        let!(:other_category) { Fabricate(:category, name: "#{category.id} name") }

        it 'uses the correct category' do
          get "/c/#{other_category.slug}/l/latest.json"
          expect(response.status).to eq(200)
          body = JSON.parse(response.body)
          expect(body["topic_list"]["topics"].first["category_id"])
            .to eq(other_category.id)
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category, parent_category_id: category.id) }

        context 'when parent and child are requested' do
          it "succeeds" do
            get "/c/#{category.slug}/#{sub_category.slug}/l/latest"
            expect(response.status).to eq(200)
          end
        end

        context 'when child is requested with the wrong parent' do
          it "responds with a 404 error" do
            get "/c/not-the-right-slug/#{sub_category.slug}/l/latest"
            expect(response.status).to eq(404)
          end
        end
      end

      describe 'feed' do
        it 'renders RSS' do
          get "/c/#{category.slug}.rss"
          expect(response.status).to eq(200)
          expect(response.content_type).to eq('application/rss+xml')
        end
      end

      describe "category default views" do
        it "has a top default view" do
          category.update_attributes!(default_view: 'top', default_top_period: 'monthly')
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to eq("monthly")
        end

        it "has a default view of nil" do
          category.update_attributes!(default_view: nil)
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of ''" do
          category.update_attributes!(default_view: '')
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of latest" do
          category.update_attributes!(default_view: 'latest')
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to be_blank
        end
      end

      describe "renders canonical tag" do
        it 'for category default view' do
          get "/c/#{category.slug}"
          expect(response.status).to eq(200)
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end

        it 'for category latest view' do
          get "/c/#{category.slug}/l/latest"
          expect(response.status).to eq(200)
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end
      end
    end
  end

  describe "topics_by" do
    before do
      sign_in(Fabricate(:user))
      Fabricate(:topic, user: user)
    end

    it "should respond with a list" do
      get "/topics/created-by/#{user.username}.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["topic_list"]["topics"].size).to eq(1)
    end
  end

  describe "private_messages" do
    it "returns 403 error when the user can't see private message" do
      sign_in(Fabricate(:user))
      get "/topics/private-messages/#{user.username}.json"
      expect(response).to be_forbidden
    end

    it "succeeds when the user can see private messages" do
      pm = Fabricate(:private_message_topic, user: Fabricate(:user))
      pm.topic_allowed_users.create!(user: user)
      sign_in(user)
      get "/topics/private-messages/#{user.username}.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["topic_list"]["topics"].size).to eq(1)
    end
  end

  describe "private_messages_sent" do
    before do
      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, user: user, topic: pm, post_number: 1)
    end

    it "returns 403 error when the user can't see private message" do
      sign_in(Fabricate(:user))
      get "/topics/private-messages-sent/#{user.username}.json"
      expect(response).to be_forbidden
    end

    it "succeeds when the user can see private messages" do
      sign_in(user)
      get "/topics/private-messages-sent/#{user.username}.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["topic_list"]["topics"].size).to eq(1)
    end
  end

  describe "private_messages_unread" do
    before do
      u = Fabricate(:user)
      pm = Fabricate(:private_message_topic, user: u)
      Fabricate(:post, user: u, topic: pm, post_number: 1)
      pm.topic_allowed_users.create!(user: user)
    end

    it "returns 403 error when the user can't see private message" do
      sign_in(Fabricate(:user))
      get "/topics/private-messages-unread/#{user.username}.json"
      expect(response).to be_forbidden
    end

    it "succeeds when the user can see private messages" do
      sign_in(user)
      get "/topics/private-messages-unread/#{user.username}.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["topic_list"]["topics"].size).to eq(1)
    end
  end

  describe 'read' do
    it 'raises an error when not logged in' do
      get "/read"
      expect(response.status).to eq(404)
    end

    context 'when logged in' do
      it "succeeds" do
        sign_in(user)
        get "/read"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "best_periods_for" do
    it "returns yearly for more than 180 days" do
      expect(ListController.best_periods_for(nil, :all)).to eq([:yearly])
      expect(ListController.best_periods_for(180.days.ago, :all)).to eq([:yearly])
    end

    it "includes monthly when less than 180 days and more than 35 days" do
      (35...180).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:monthly, :yearly])
      end
    end

    it "includes weekly when less than 35 days and more than 8 days" do
      (8...35).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:weekly, :monthly, :yearly])
      end
    end

    it "includes daily when less than 8 days" do
      (0...8).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:daily, :weekly, :monthly, :yearly])
      end
    end

    it "returns default even for more than 180 days" do
      expect(ListController.best_periods_for(nil, :monthly)).to eq([:monthly, :yearly])
      expect(ListController.best_periods_for(180.days.ago, :monthly)).to eq([:monthly, :yearly])
    end

    it "returns default even when less than 180 days and more than 35 days" do
      (35...180).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :weekly)).to eq([:weekly, :monthly, :yearly])
      end
    end

    it "returns default even when less than 35 days and more than 8 days" do
      (8...35).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :daily)).to eq([:daily, :weekly, :monthly, :yearly])
      end
    end

    it "doesn't return default when set to all" do
      expect(ListController.best_periods_for(nil, :all)).to eq([:yearly])
    end

    it "doesn't return value twice when matches default" do
      expect(ListController.best_periods_for(nil, :yearly)).to eq([:yearly])
    end
  end

  describe "categories suppression" do
    let(:category_one) { Fabricate(:category) }
    let(:sub_category) { Fabricate(:category, parent_category: category_one, suppress_from_latest: true) }
    let!(:topic_in_sub_category) { Fabricate(:topic, category: sub_category) }

    let(:category_two) { Fabricate(:category, suppress_from_latest: true) }
    let!(:topic_in_category_two) { Fabricate(:topic, category: category_two) }

    it "suppresses categories from the latest list" do
      get "/#{SiteSetting.homepage}.json"
      expect(response.status).to eq(200)

      topic_titles = JSON.parse(response.body)["topic_list"]["topics"].map { |t| t["title"] }
      expect(topic_titles).not_to include(topic_in_sub_category.title, topic_in_category_two.title)
    end

    it "does not suppress" do
      get "/#{SiteSetting.homepage}.json", params: { category: category_one.id }
      expect(response.status).to eq(200)

      topic_titles = JSON.parse(response.body)["topic_list"]["topics"].map { |t| t["title"] }
      expect(topic_titles).to include(topic_in_sub_category.title)
    end
  end

  describe "safe mode" do
    it "handles safe mode" do
      get "/latest"
      expect(response.body).to match(/plugin\.js/)
      expect(response.body).to match(/plugin-third-party\.js/)

      get "/latest", params: { safe_mode: "no_plugins" }
      expect(response.body).not_to match(/plugin\.js/)
      expect(response.body).not_to match(/plugin-third-party\.js/)

      get "/latest", params: { safe_mode: "only_official" }
      expect(response.body).to match(/plugin\.js/)
      expect(response.body).not_to match(/plugin-third-party\.js/)
    end
  end
end
