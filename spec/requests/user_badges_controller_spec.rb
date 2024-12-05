# frozen_string_literal: true

RSpec.describe UserBadgesController do
  fab!(:user)
  fab!(:admin)
  fab!(:badge)

  before { user.user_stat.update!(post_count: 1) }

  describe "#index" do
    fab!(:badge) { Fabricate(:badge, target_posts: true, show_posts: false) }

    it "does not leak private info" do
      p = create_post
      UserBadge.create!(
        badge: badge,
        user: user,
        post_id: p.id,
        granted_by_id: -1,
        granted_at: Time.now,
      )

      get "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["topics"]).to eq(nil)
      expect(parsed["badges"].length).to eq(1)
      expect(parsed["user_badge_info"]["user_badges"][0]["post_id"]).to eq(nil)
    end

    it "fails when badges are disabled" do
      SiteSetting.enable_badges = false
      get "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(404)
    end

    it "only accepts valid offset params" do
      get "/user_badges.json", params: { badge_id: badge.id, offset: -1 }
      expect(response.status).to eq(400)

      get "/user_badges.json", params: { badge_id: badge.id, offset: 100 }
      expect(response.status).to eq(200)
    end

    it "requires username or badge_id to be specified" do
      get "/user_badges.json"
      expect(response.status).to eq(400)
    end
  end

  describe "#show" do
    fab!(:post)
    fab!(:private_message_post)
    let(:topic) { post.topic }
    let(:private_message_topic) { private_message_post.topic }
    fab!(:group)
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:restricted_topic) { Fabricate(:topic, category: private_category) }
    fab!(:restricted_post) { Fabricate(:post, topic: restricted_topic) }
    fab!(:badge) { Fabricate(:badge, show_posts: true) }
    fab!(:user_badge) { Fabricate(:user_badge, user: user, badge: badge, post: post) }
    fab!(:user_badge_2) { Fabricate(:user_badge, badge: badge, post: private_message_post) }
    fab!(:user_badge_3) { Fabricate(:user_badge, badge: badge, post: restricted_post) }

    it "returns user_badges for a user" do
      get "/user-badges/#{user.username}.json"

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["user_badges"].length).to eq(1)
    end

    it "returns user_badges for a user with period in username" do
      user.update!(username: "myname.test")
      get "/user-badges/#{user.username}", xhr: true

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["user_badges"].length).to eq(1)
    end

    it "returns user_badges for a badge" do
      get "/user_badges.json", params: { badge_id: badge.id }

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["user_badge_info"]["user_badges"].length).to eq(3)
    end

    it "includes counts when passed the aggregate argument" do
      get "/user-badges/#{user.username}.json", params: { grouped: true }

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["user_badges"].first.has_key?("count")).to eq(true)
    end

    context "for post and topic attributes associated with user badge" do
      it "does not include the attributes for the private topic when user is anon" do
        get "/user_badges.json", params: { badge_id: badge.id }

        expect(response.status).to eq(200)

        parsed = response.parsed_body

        expect(parsed["topics"].map { |t| t["id"] }).to contain_exactly(post.topic_id)

        parsed_user_badges = parsed["user_badge_info"]["user_badges"]

        expect(parsed_user_badges.map { |ub| ub["post_id"] }.compact).to contain_exactly(post.id)
        expect(parsed_user_badges.map { |ub| ub["post_number"] }.compact).to contain_exactly(
          post.post_number,
        )
      end

      it "does not include the attributes for topics which the current user cannot see" do
        sign_in(user)

        get "/user_badges.json", params: { badge_id: badge.id }

        expect(response.status).to eq(200)

        parsed = response.parsed_body

        expect(parsed["topics"].map { |t| t["id"] }).to contain_exactly(post.topic_id)

        parsed_user_badges = parsed["user_badge_info"]["user_badges"]

        expect(parsed_user_badges.map { |ub| ub["post_id"] }.compact).to contain_exactly(post.id)
        expect(parsed_user_badges.map { |ub| ub["post_number"] }.compact).to contain_exactly(
          post.post_number,
        )
      end

      it "includes the attributes for regular topic, private messages and restricted topics which the current user can see" do
        group.add(user)
        private_message_topic.allowed_users << user

        sign_in(user)

        get "/user_badges.json", params: { badge_id: badge.id }

        expect(response.status).to eq(200)

        parsed = response.parsed_body

        expect(parsed["topics"].map { |t| t["id"] }).to contain_exactly(
          post.topic_id,
          private_message_post.topic_id,
          restricted_post.topic_id,
        )

        parsed_user_badges = parsed["user_badge_info"]["user_badges"]

        expect(parsed_user_badges.map { |ub| ub["post_id"] }.compact).to contain_exactly(
          post.id,
          private_message_post.id,
          restricted_post.id,
        )

        expect(parsed_user_badges.map { |ub| ub["post_number"] }.compact).to contain_exactly(
          post.post_number,
          private_message_post.post_number,
          restricted_post.post_number,
        )
      end
    end

    context "with hidden profiles" do
      before { user.user_option.update_columns(hide_profile: true) }

      it "returns 404 if `hide_profile` user option is checked" do
        get "/user-badges/#{user.username}.json"
        expect(response.status).to eq(404)
      end

      it "returns user_badges if `allow_users_to_hide_profile` is false" do
        SiteSetting.allow_users_to_hide_profile = false

        get "/user-badges/#{user.username}.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#create" do
    it "requires username to be specified" do
      post "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(400)
    end

    it "does not allow regular users to grant badges" do
      sign_in(Fabricate(:user))

      post "/user_badges.json", params: { badge_id: badge.id, username: user.username }

      expect(response.status).to eq(403)
    end

    it "grants badges from staff" do
      post_1 = create_post

      sign_in(admin)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
             reason: Discourse.base_url + post_1.url,
           }

      expect(response.status).to eq(200)

      user_badge = UserBadge.find_by(user: user, badge: badge)

      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(admin)
      expect(user_badge.post_id).to eq(post_1.id)
      expect(UserHistory.where(acting_user: admin, target_user: user).count).to eq(1)
    end

    it "does not grant badges from regular api calls" do
      api_key = Fabricate(:api_key, user: user)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
             api_key: api_key.key,
           }

      expect(response.status).to eq(403)
    end

    it "grants badges from master api calls" do
      api_key = Fabricate(:api_key)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
           },
           headers: {
             HTTP_API_KEY: api_key.key,
             HTTP_API_USERNAME: "system",
           }

      expect(response.status).to eq(200)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(Discourse.system_user)
      expect(UserHistory.where(acting_user: Discourse.system_user, target_user: user).count).to eq(
        0,
      )
    end

    it "will trigger :user_badge_granted" do
      sign_in(Fabricate(:admin))

      events =
        DiscourseEvent
          .track_events do
            post "/user_badges.json", params: { badge_id: badge.id, username: user.username }
          end
          .map { |event| event[:event_name] }

      expect(events).to include(:user_badge_granted)
    end

    it "does not grant badge when external link is used in reason" do
      post = create_post

      sign_in(admin)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
             reason: "http://example.com/" + post.url,
           }

      expect(response.status).to eq(400)
    end

    it "does not grant badge if invalid discourse post/topic link is used in reason" do
      post = create_post

      sign_in(admin)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
             reason: Discourse.base_url + "/random_url/" + post.url,
           }

      expect(response.status).to eq(400)
    end

    it "grants badge when valid post/topic link is given in reason" do
      post = create_post

      sign_in(admin)

      post "/user_badges.json",
           params: {
             badge_id: badge.id,
             username: user.username,
             reason: Discourse.base_url + post.url,
           }

      expect(response.status).to eq(200)
    end

    describe "with relative_url_root" do
      it "grants badge when valid post/topic link is given in reason" do
        set_subfolder "/discuss"

        post = create_post

        sign_in(admin)

        post "/user_badges.json",
             params: {
               badge_id: badge.id,
               username: user.username,
               reason: "#{Discourse.base_url}#{post.url}",
             }

        expect(response.status).to eq(200)

        expect(UserBadge.exists?(badge_id: badge.id, post_id: post.id, granted_by: admin.id)).to eq(
          true,
        )
      end
    end
  end

  describe "#destroy" do
    let!(:user_badge) do
      UserBadge.create(
        badge: badge,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    it "checks that the user is authorized to revoke a badge" do
      delete "/user_badges/#{user_badge.id}.json"
      expect(response.status).to eq(403)
    end

    it "revokes the badge" do
      sign_in(admin)
      delete "/user_badges/#{user_badge.id}.json"

      expect(response.status).to eq(200)
      expect(UserBadge.find_by(id: user_badge.id)).to eq(nil)
      expect(UserHistory.where(acting_user: admin, target_user: user).count).to eq(1)
    end

    it "will trigger :user_badge_removed" do
      sign_in(Fabricate(:admin))

      events =
        DiscourseEvent
          .track_events { delete "/user_badges/#{user_badge.id}.json" }
          .map { |event| event[:event_name] }

      expect(events).to include(:user_badge_removed)
    end
  end

  describe "#favorite" do
    let!(:user_badge) do
      UserBadge.create(
        badge: badge,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    it "checks that the user is authorized to favorite the badge" do
      sign_in(Fabricate(:admin))
      put "/user_badges/#{user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(403)
    end

    it "checks that the user has less than max_favorites_badges favorited badges" do
      sign_in(user)
      UserBadge.create(
        badge: Fabricate(:badge),
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        is_favorite: true,
      )
      UserBadge.create(
        badge: Fabricate(:badge),
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        is_favorite: true,
      )

      put "/user_badges/#{user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(400)

      SiteSetting.max_favorite_badges = 3

      put "/user_badges/#{user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(204)
    end

    it "favorites a badge" do
      sign_in(user)
      put "/user_badges/#{user_badge.id}/toggle_favorite.json"

      expect(response.status).to eq(204)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge.is_favorite).to eq(true)
    end

    it "unfavorites a badge" do
      sign_in(user)
      user_badge.toggle!(:is_favorite)
      put "/user_badges/#{user_badge.id}/toggle_favorite.json"

      expect(response.status).to eq(204)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge.is_favorite).to eq(false)
    end

    it "works with multiple grants" do
      SiteSetting.max_favorite_badges = 2

      sign_in(user)

      badge = Fabricate(:badge, multiple_grant: true)
      user_badge =
        UserBadge.create(
          badge: badge,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
          seq: 0,
          is_favorite: true,
        )
      user_badge2 =
        UserBadge.create(
          badge: badge,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
          seq: 1,
          is_favorite: true,
        )
      other_badge = Fabricate(:badge)
      other_user_badge =
        UserBadge.create(
          badge: other_badge,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
        )

      put "/user_badges/#{user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(204)
      expect(user_badge.reload.is_favorite).to eq(false)
      expect(user_badge2.reload.is_favorite).to eq(false)

      put "/user_badges/#{user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(204)
      expect(user_badge.reload.is_favorite).to eq(true)
      expect(user_badge2.reload.is_favorite).to eq(true)

      put "/user_badges/#{other_user_badge.id}/toggle_favorite.json"
      expect(response.status).to eq(204)
      expect(other_user_badge.reload.is_favorite).to eq(true)
    end
  end
end
