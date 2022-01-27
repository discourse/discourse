# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ListController do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:group) { Fabricate(:group, name: "AwesomeGroup") }
  fab!(:admin) { Fabricate(:admin) }

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
      get "/latest.json?no_definitions=true&no_subcategories=false&page=1&_=1534296100767"
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

      get "/latest?search="
      expect(response.status).to eq(200)

      get "/latest.json?topic_ids%5B%5D=14583&topic_ids%5B%5D=14584"
      expect(response.status).to eq(200)

      get "/latest.json?topic_ids=14583%2C14584"
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
      parsed = response.parsed_body
      expect(parsed["topic_list"]["topics"].length).to eq(1)
    end

    it "shows correct title if topic list is set for homepage" do
      get "/latest"

      expect(response.body).to have_tag "title", text: "Discourse"

      SiteSetting.short_site_description = "Best community"
      get "/latest"

      expect(response.body).to have_tag "title", text: "Discourse - Best community"
    end
  end

  describe "categories and X" do
    let(:category) { Fabricate(:category_with_definition) }
    let(:sub_category) { Fabricate(:category_with_definition, parent_category: category) }

    it "returns top topics" do
      Fabricate(:topic, like_count: 1000, posts_count: 100)
      TopTopic.refresh!

      get "/categories_and_top.json"
      data = response.parsed_body
      expect(data["topic_list"]["topics"].length).to eq(1)

      get "/categories_and_latest.json"
      data = response.parsed_body
      expect(data["topic_list"]["topics"].length).to eq(2)
    end

    it "returns topics from subcategories when no_subcategories=false" do
      Fabricate(:topic, category: sub_category)
      get "/c/#{category.slug}/#{category.id}/l/latest.json?no_subcategories=false"
      expect(response.parsed_body["topic_list"]["topics"].length).to eq(2)
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
    fab!(:user) { Fabricate(:user) }
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:admin) { Fabricate(:admin) }
    let(:tag) { Fabricate(:tag) }
    let(:private_message) { Fabricate(:private_message_topic, user: admin) }

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

    it 'should fail for staff users if disabled' do
      SiteSetting.allow_staff_to_tag_pms = false

      [moderator, admin].each do |user|
        sign_in(user)
        get "/topics/private-messages-tags/#{user.username}/#{tag.name}.json"
        expect(response.status).to eq(404)
      end
    end

    it 'should be success for staff users' do
      [moderator, admin].each do |user|
        sign_in(user)
        get "/topics/private-messages-tags/#{user.username}/#{tag.name}.json"
        expect(response.status).to eq(200)
      end
    end

    it 'should work for tag with unicode name' do
      unicode_tag = Fabricate(:tag, name: 'hello-🇺🇸')
      Fabricate(:topic_tag, tag: unicode_tag, topic: private_message)

      sign_in(admin)
      get "/topics/private-messages-tags/#{admin.username}/#{UrlHelper.encode_component(unicode_tag.name)}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_list"]["topics"].first["id"])
        .to eq(private_message.id)
    end
  end

  describe '#private_messages_group' do
    fab!(:user) { Fabricate(:user) }

    describe 'with personal_messages disabled' do
      let!(:topic) { Fabricate(:private_message_topic, allowed_groups: [group]) }

      before do
        group.add(user)
        SiteSetting.enable_personal_messages = false
      end

      it 'should display group private messages for an admin' do
        sign_in(Fabricate(:admin))

        get "/topics/private-messages-group/#{user.username}/#{group.name}.json"

        expect(response.status).to eq(200)

        expect(response.parsed_body["topic_list"]["topics"].first["id"])
          .to eq(topic.id)
      end

      it 'should display moderator group private messages for a moderator' do
        moderator = Fabricate(:moderator)
        group = Group.find(Group::AUTO_GROUPS[:moderators])
        topic = Fabricate(:private_message_topic, allowed_groups: [group])

        sign_in(moderator)

        get "/topics/private-messages-group/#{moderator.username}/#{group.name}.json"
        expect(response.status).to eq(200)
      end

      it "should not display group private messages for a moderator's group" do
        moderator = Fabricate(:moderator)
        sign_in(moderator)
        group.add(moderator)

        get "/topics/private-messages-group/#{user.username}/#{group.name}.json"

        expect(response.status).to eq(404)
      end
    end

    describe 'with unicode_usernames' do
      before do
        group.add(user)
        sign_in(user)
        SiteSetting.unicode_usernames = false
      end

      it 'should return the right response when user does not belong to group' do
        Fabricate(:private_message_topic, allowed_groups: [group])

        group.remove(user)

        get "/topics/private-messages-group/#{user.username}/#{group.name}.json"

        expect(response.status).to eq(404)
      end

      it 'should return the right response' do
        topic = Fabricate(:private_message_topic, allowed_groups: [group])
        get "/topics/private-messages-group/#{user.username}/awesomegroup.json"

        expect(response.status).to eq(200)

        expect(response.parsed_body["topic_list"]["topics"].first["id"])
          .to eq(topic.id)
      end
    end

    describe 'with unicode_usernames' do
      before do
        sign_in(user)
        SiteSetting.unicode_usernames = true
      end

      it 'Returns a 200 with unicode group name' do
        unicode_group = Fabricate(:group, name: '群群组')
        unicode_group.add(user)
        topic = Fabricate(:private_message_topic, allowed_groups: [unicode_group])
        get "/topics/private-messages-group/#{user.username}/#{UrlHelper.encode_component(unicode_group.name)}.json"
        expect(response.status).to eq(200)

        expect(response.parsed_body["topic_list"]["topics"].first["id"])
          .to eq(topic.id)
      end
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
          expect(response.parsed_body["topic_list"]).to be_present
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

        topics = response.parsed_body["topic_list"]["topics"]

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
      expect(response.media_type).to eq('application/rss+xml')
      expect(response.headers['X-Robots-Tag']).to eq('noindex')
    end

    it 'renders latest RSS with query params' do
      get "/latest.rss?status=closed"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq('application/rss+xml')
      expect(response.body).to_not include("<item>")
    end

    it 'renders links correctly with subfolder' do
      set_subfolder "/forum"
      _post = Fabricate(:post, topic: topic, user: user)
      get "/latest.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("/forum/forum")
      expect(response.body).to include("http://test.localhost/forum/t/#{topic.slug}")
    end

    it 'renders top RSS' do
      get "/top.rss"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq('application/rss+xml')
    end

    it 'errors for invalid periods on top RSS' do
      get "/top.rss?period=decadely"
      expect(response.status).to eq(400)
    end

    TopTopic.periods.each do |period|
      it "renders #{period} top RSS" do
        get "/top.rss?period=#{period}"
        expect(response.status).to eq(200)
        expect(response.media_type).to eq('application/rss+xml')
      end
    end
  end

  describe 'Top' do
    it 'renders top' do
      get "/top"
      expect(response.status).to eq(200)
    end

    it 'renders top with a period' do
      get "/top?period=weekly"
      expect(response.status).to eq(200)
    end

    it 'errors for invalid periods on top' do
      get "/top?period=decadely"
      expect(response.status).to eq(400)
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
          get "/c/#{category.slug}/#{category.id}/l/latest"
          expect(response.status).to eq(200)
        end
      end

      context 'with encoded slug in the category' do
        let(:category) { Fabricate(:category, slug: "தமிழ்") }

        before do
          SiteSetting.slug_generation_method = "encoded"
        end

        it "succeeds" do
          get "/c/#{category.slug}/#{category.id}/l/latest"
          expect(response.status).to eq(200)
        end
      end

      context 'with a link that has a parent slug, slug and id in its path' do
        let(:child_category) { Fabricate(:category_with_definition, parent_category: category) }

        context "with valid slug" do
          it "succeeds" do
            get "/c/#{category.slug}/#{child_category.slug}/#{child_category.id}/l/latest"
            expect(response.status).to eq(200)
          end
        end

        context "with invalid slug" do
          it "redirects" do
            get "/c/random_slug/another_random_slug/#{child_category.id}/l/latest"
            expect(response).to redirect_to("#{child_category.url}/l/latest")
          end
        end
      end

      context 'another category exists with a number at the beginning of its name' do
        # One category has another category's id at the beginning of its name
        let!(:other_category) {
          # Our validations don't allow this to happen now, but did historically
          Fabricate(:category_with_definition, name: "#{category.id} name", slug: 'will-be-changed').tap do |category|
            category.update_column(:slug, "#{category.id}-name")
          end
        }

        it 'uses the correct category' do
          get "/c/#{other_category.slug}/#{other_category.id}/l/latest.json"
          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body["topic_list"]["topics"].first["category_id"])
            .to eq(other_category.id)
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category_with_definition, parent_category_id: category.id) }

        context 'when parent and child are requested' do
          it "succeeds" do
            get "/c/#{category.slug}/#{sub_category.slug}/#{sub_category.id}/l/latest"
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
          get "/c/#{category.slug}/#{category.id}.rss"
          expect(response.status).to eq(200)
          expect(response.media_type).to eq('application/rss+xml')
        end

        it "renders RSS in subfolder correctly" do
          set_subfolder "/forum"
          get "/c/#{category.slug}/#{category.id}.rss"
          expect(response.status).to eq(200)
          expect(response.body).to_not include("/forum/forum")
          expect(response.body).to include("http://test.localhost/forum/c/#{category.slug}")
        end
      end

      describe "category default views" do
        it "has a top default view" do
          category.update!(default_view: 'top', default_top_period: 'monthly')
          get "/c/#{category.slug}/#{category.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["topic_list"]["for_period"]).to eq("monthly")
        end

        it "has a default view of nil" do
          category.update!(default_view: nil)
          get "/c/#{category.slug}/#{category.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of ''" do
          category.update!(default_view: '')
          get "/c/#{category.slug}/#{category.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["topic_list"]["for_period"]).to be_blank
        end

        it "has a default view of latest" do
          category.update!(default_view: 'latest')
          get "/c/#{category.slug}/#{category.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["topic_list"]["for_period"]).to be_blank
        end
      end

      describe "renders canonical tag" do
        it 'for category default view' do
          get "/c/#{category.slug}/#{category.id}"
          expect(response.status).to eq(200)
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end

        it 'for category latest view' do
          get "/c/#{category.slug}/#{category.id}/l/latest"
          expect(response.status).to eq(200)
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end
      end

      context "renders correct title" do
        let!(:amazing_category) { Fabricate(:category_with_definition, name: "Amazing Category") }

        it 'for category default view' do
          get "/c/#{amazing_category.slug}/#{amazing_category.id}"

          expect(response.body).to have_tag "title", text: "Amazing Category - Discourse"
        end

        it 'for category latest view' do
          SiteSetting.short_site_description = "Best community"
          get "/c/#{amazing_category.slug}/#{amazing_category.id}/l/latest"

          expect(response.body).to have_tag "title", text: "Amazing Category - Discourse"
        end
      end
    end
  end

  describe "topics_by" do
    fab!(:topic2) { Fabricate(:topic, user: user) }
    fab!(:user2) { Fabricate(:user) }

    before do
      sign_in(user2)
    end

    it "should respond with a list" do
      get "/topics/created-by/#{user.username}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_list"]["topics"].size).to eq(2)
    end

    it "should work with period in username" do
      user.update!(username: "myname.test")
      get "/topics/created-by/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_list"]["topics"].size).to eq(2)
    end

    context 'when `hide_profile_and_presence` is true' do
      before do
        user.user_option.update_columns(hide_profile_and_presence: true)
      end

      it "returns 404" do
        get "/topics/created-by/#{user.username}.json"
        expect(response.status).to eq(404)
      end

      it "should respond with a list when `allow_users_to_hide_profile` is false" do
        SiteSetting.allow_users_to_hide_profile = false
        get "/topics/created-by/#{user.username}.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["topic_list"]["topics"].size).to eq(2)
      end
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
      json = response.parsed_body
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
      json = response.parsed_body
      expect(json["topic_list"]["topics"].size).to eq(1)
    end
  end

  describe "#private_messages_unread" do
    fab!(:pm_user) { Fabricate(:user) }

    fab!(:pm) do
      Fabricate(:private_message_topic).tap do |t|
        t.allowed_users << pm_user
        create_post(user: pm_user, topic_id: t.id)
      end
    end

    it "returns 404 when the user can't see private message" do
      sign_in(Fabricate(:user))
      get "/topics/private-messages-unread/#{pm_user.username}.json"
      expect(response.status).to eq(404)
    end

    it "succeeds when the user can see private messages" do
      TopicUser.find_by(topic: pm, user: pm_user).update!(
        notification_level: TopicUser.notification_levels[:tracking],
        last_read_post_number: 0,
      )

      sign_in(pm_user)
      get "/topics/private-messages-unread/#{pm_user.username}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_list"]["topics"].size).to eq(1)
      expect(json["topic_list"]["topics"][0]["id"]).to eq(pm.id)
    end
  end

  describe "#private_messages_warnings" do
    fab!(:target_user) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }
    fab!(:moderator1) { Fabricate(:moderator) }
    fab!(:moderator2) { Fabricate(:moderator) }

    let(:create_args) do
      { title: 'you need a warning buddy!',
        raw: "you did something bad and I'm telling you about it!",
        is_warning: true,
        target_usernames: target_user.username,
        archetype: Archetype.private_message }
    end

    let(:warning_post) do
      creator = PostCreator.new(moderator1, create_args)
      creator.create
    end
    let(:warning_topic) { warning_post.topic }

    before do
      warning_topic
    end

    it "returns 403 error for unrelated users" do
      sign_in(Fabricate(:user))
      get "/topics/private-messages-warnings/#{target_user.username}.json"
      expect(response.status).to eq(403)
    end

    it "shows the warning to moderators and admins" do
      [moderator1, moderator2, admin].each do |viewer|
        sign_in(viewer)
        get "/topics/private-messages-warnings/#{target_user.username}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["topic_list"]["topics"].size).to eq(1)
        expect(json["topic_list"]["topics"][0]["id"]).to eq(warning_topic.id)
      end
    end

    it "does not show the warning as applying to the authoring moderator" do
      sign_in(admin)
      get "/topics/private-messages-warnings/#{moderator1.username}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_list"]["topics"].size).to eq(0)
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

  describe "user_topics_feed" do
    it "returns 404 if `hide_profile_and_presence` user option is checked" do
      user.user_option.update_columns(hide_profile_and_presence: true)
      get "/u/#{user.username}/activity/topics.rss"
      expect(response.status).to eq(404)
    end
  end

  describe "set_category" do
    let(:category) { Fabricate(:category_with_definition) }
    let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
    let(:subsubcategory) { Fabricate(:category_with_definition, parent_category_id: subcategory.id) }

    before do
      SiteSetting.max_category_nesting = 3
    end

    it "redirects to URL with the updated slug" do
      get "/c/hello/world/bye/#{subsubcategory.id}"
      expect(response.status).to eq(301)
      expect(response).to redirect_to("/c/#{category.slug}/#{subcategory.slug}/#{subsubcategory.slug}/#{subsubcategory.id}")

      get "/c/#{category.slug}/#{subcategory.slug}/#{subsubcategory.slug}/#{subsubcategory.id}"
      expect(response.status).to eq(200)
    end

    it "redirects to URL with correct case slug" do
      category.update!(slug: "hello")

      get "/c/Hello/#{category.id}"
      expect(response).to redirect_to("/c/hello/#{category.id}")

      get "/c/hello/#{category.id}"
      expect(response.status).to eq(200)
    end

    context "does not create a redirect loop" do
      it "with encoded slugs" do
        category = Fabricate(:category)
        category.update_columns(slug: CGI.escape("systèmes"))

        get "/c/syst%C3%A8mes/#{category.id}"
        expect(response.status).to eq(200)
      end

      it "with lowercase encoded slugs" do
        category = Fabricate(:category)
        category.update_columns(slug: CGI.escape("systèmes").downcase)

        get "/c/syst%C3%A8mes/#{category.id}"
        expect(response.status).to eq(200)
      end
    end

    context "with subfolder" do
      it "main category redirects to URL containing the updated slug" do
        set_subfolder "/forum"
        get "/c/#{category.slug}"

        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/c/#{category.slug}/#{category.id}")
      end

      it "sub-sub-category redirects to URL containing the updated slug" do
        set_subfolder "/forum"
        get "/c/hello/world/bye/#{subsubcategory.id}"

        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/c/#{category.slug}/#{subcategory.slug}/#{subsubcategory.slug}/#{subsubcategory.id}")
      end
    end
  end

  describe "shared drafts" do
    fab!(:category1) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }

    fab!(:topic1) { Fabricate(:topic, category: category1) }
    fab!(:topic2) { Fabricate(:topic, category: category2) }

    fab!(:shared_draft_topic) { Fabricate(:topic, category: category1) }
    fab!(:shared_draft) { Fabricate(:shared_draft, topic: shared_draft_topic, category: category2) }

    it "are not displayed if they are disabled" do
      SiteSetting.shared_drafts_category = ""
      sign_in(admin)

      get "/c/#{category1.slug}/#{category1.id}.json"
      expect(response.parsed_body['topic_list']['shared_drafts']).to eq(nil)
      expect(response.parsed_body['topic_list']['topics'].map { |t| t['id'] }).to contain_exactly(topic1.id, shared_draft_topic.id)
    end

    it "are displayed in both shared drafts category and target category" do
      SiteSetting.shared_drafts_category = category1.id
      sign_in(admin)

      get "/c/#{category1.slug}/#{category1.id}.json"
      expect(response.parsed_body['topic_list']['shared_drafts']).to be_nil
      expect(response.parsed_body['topic_list']['topics'].map { |t| t['id'] }).to contain_exactly(topic1.id, shared_draft_topic.id)

      get "/c/#{category2.slug}/#{category2.id}.json"
      expect(response.parsed_body['topic_list']['shared_drafts'].map { |t| t['id'] }).to contain_exactly(shared_draft_topic.id)
      expect(response.parsed_body['topic_list']['topics'].map { |t| t['id'] }).to contain_exactly(topic2.id)
    end
  end
end
