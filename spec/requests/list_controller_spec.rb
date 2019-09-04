# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ListController do
  let(:topic) { Fabricate(:topic, user: user) }
  let(:group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  before do
    admin  # to skip welcome wizard at home page `/`
    SiteSetting.top_menu = 'latest|new|unread|categories'
  end

  describe '#index' do
    it "does not return a 500 for invalid input" do
      get "/latest?min_posts=bob"
      expect(response.status).to eq(400)

      get "/latest?max_posts=bob"
      expect(response.status).to eq(400)

      get "/latest?exclude_category_ids=bob"
      expect(response.status).to eq(400)

      get "/latest?exclude_category_ids[]=bob"
      expect(response.status).to eq(400)

      get "/latest?max_posts=1111111111111111111111111111111111111111"
      expect(response.status).to eq(400)

      get "/latest?page=-1"
      expect(response.status).to eq(400)

      get "/latest?page=2147483648"
      expect(response.status).to eq(400)

      get "/latest?page=1111111111111111111111111111111111111111"
      expect(response.status).to eq(400)
    end

    it "returns 200 for legit requests" do
      get "/latest.json?exclude_category_ids%5B%5D=69&exclude_category_ids%5B%5D=70&no_definitions=true&no_subcategories=false&page=1&_=1534296100767"
      expect(response.status).to eq(200)

      get "/latest.json?exclude_category_ids=-1"
      expect(response.status).to eq(200)

      get "/latest.json?max_posts=12"
      expect(response.status).to eq(200)

      get "/latest.json?min_posts=0"
      expect(response.status).to eq(200)

      get "/latest?page=0"
      expect(response.status).to eq(200)

      get "/latest?page=1"
      expect(response.status).to eq(200)

      get "/latest.json?page=2147483647"
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

    it "shows correct title if topic list is set for homepage" do
      get "/"

      expect(response.body).to have_tag "title", text: "Discourse"

      SiteSetting.short_site_description = "Best community"
      get "/"

      expect(response.body).to have_tag "title", text: "Discourse - Best community"
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

      describe 'group restricted to logged-on-users' do
        before { group.update!(visibility_level: Group.visibility_levels[:logged_on_users]) }

        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(403)
        end
      end

      describe 'restricted group' do
        before { group.update!(visibility_level: Group.visibility_levels[:staff]) }

        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(403)
        end
      end

      describe 'group members visibility restricted to logged-on-users' do
        before { group.update!(members_visibility_level: Group.visibility_levels[:logged_on_users]) }

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

      describe 'group restricted to logged-on-users' do
        before { group.update!(visibility_level: Group.visibility_levels[:logged_on_users]) }

        it 'should return the right response' do
          get "/topics/groups/#{group.name}.json"

          expect(response.status).to eq(200)
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

    it 'renders links correctly with subfolder' do
      GlobalSetting.stubs(:relative_url_root).returns('/forum')
      Discourse.stubs(:base_uri).returns("/forum")
      post = Fabricate(:post, topic: topic, user: user)
      get "/latest.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("/forum/forum")
      expect(response.body).to include("http://test.localhost/forum/t/#{topic.slug}")
      expect(response.body).to include("http://test.localhost/forum/u/#{post.user.username}")
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
      let(:category) { Fabricate(:category_with_definition) }
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
        let(:child_category) { Fabricate(:category_with_definition, parent_category: category) }

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
        let!(:other_category) { Fabricate(:category_with_definition, name: "#{category.id} name") }

        it 'uses the correct category' do
          get "/c/#{other_category.slug}/l/latest.json"
          expect(response.status).to eq(200)
          body = JSON.parse(response.body)
          expect(body["topic_list"]["topics"].first["category_id"])
            .to eq(other_category.id)
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category_with_definition, parent_category_id: category.id) }

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

        it "renders RSS in subfolder correctly" do
          GlobalSetting.stubs(:relative_url_root).returns('/forum')
          Discourse.stubs(:base_uri).returns("/forum")
          get "/c/#{category.slug}.rss"
          expect(response.status).to eq(200)
          expect(response.body).to_not include("/forum/forum")
          expect(response.body).to include("http://test.localhost/forum/c/#{category.slug}")
        end
      end

      describe "category default views" do
        it "has a top default view" do
          category.update!(default_view: 'top', default_top_period: 'monthly')
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to eq("monthly")
        end

        it "has a default view of nil" do
          category.update!(default_view: nil)
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of ''" do
          category.update!(default_view: '')
          get "/c/#{category.slug}.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of latest" do
          category.update!(default_view: 'latest')
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

      context "renders correct title" do
        let!(:amazing_category) { Fabricate(:category_with_definition, name: "Amazing Category") }

        it 'for category default view' do
          get "/c/#{amazing_category.slug}"

          expect(response.body).to have_tag "title", text: "Amazing Category - Discourse"
        end

        it 'for category latest view' do
          SiteSetting.short_site_description = "Best community"
          get "/c/#{amazing_category.slug}/l/latest"

          expect(response.body).to have_tag "title", text: "Amazing Category - Discourse"
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

    it "should work with period in username" do
      user.update!(username: "myname.test")
      get "/topics/created-by/#{user.username}", xhr: true
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
    it "works" do
      expect(ListController.best_periods_for(nil)).to eq([:all])
      expect(ListController.best_periods_for(5.years.ago)).to eq([:all])
      expect(ListController.best_periods_for(2.years.ago)).to eq([:yearly, :all])
      expect(ListController.best_periods_for(6.months.ago)).to eq([:quarterly, :yearly, :all])
      expect(ListController.best_periods_for(2.months.ago)).to eq([:monthly, :quarterly, :yearly, :all])
      expect(ListController.best_periods_for(2.weeks.ago)).to eq([:weekly, :monthly, :quarterly, :yearly, :all])
      expect(ListController.best_periods_for(2.days.ago)).to eq([:daily, :weekly, :monthly, :quarterly, :yearly, :all])
    end

    it "supports default period" do
      expect(ListController.best_periods_for(nil, :yearly)).to eq([:yearly, :all])
      expect(ListController.best_periods_for(nil, :quarterly)).to eq([:quarterly, :all])
      expect(ListController.best_periods_for(nil, :monthly)).to eq([:monthly, :all])
      expect(ListController.best_periods_for(nil, :weekly)).to eq([:weekly, :all])
      expect(ListController.best_periods_for(nil, :daily)).to eq([:daily, :all])
    end
  end

  describe "categories suppression" do
    let(:category_one) { Fabricate(:category_with_definition) }
    let(:sub_category) { Fabricate(:category_with_definition, parent_category: category_one, suppress_from_latest: true) }
    let!(:topic_in_sub_category) { Fabricate(:topic, category: sub_category) }

    let(:category_two) { Fabricate(:category_with_definition, suppress_from_latest: true) }
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
end
