# frozen_string_literal: true

RSpec.describe PostSerializer do
  fab!(:post)

  context "with a post with lots of actions" do
    fab!(:actor) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:admin)
    let(:acted_ids) do
      PostActionType.public_types.values.concat(
        %i[notify_user spam].map { |k| PostActionType.types[k] },
      )
    end

    def visible_actions_for(user)
      serializer = PostSerializer.new(post, scope: Guardian.new(user), root: false)
      # NOTE this is messy, we should extract all this logic elsewhere
      serializer.post_actions = PostAction.counts_for([post], actor)[post.id] if user.try(:id) ==
        actor.id
      actions = serializer.as_json[:actions_summary]
      lookup = PostActionType.types.invert
      actions.keep_if { |a| (a[:count] || 0) > 0 }.map { |a| lookup[a[:id]] }
    end

    before do
      acted_ids.each { |id| PostActionCreator.new(actor, post, id).perform }
      post.reload
    end

    it "displays the correct info" do
      expect(visible_actions_for(actor).sort).to eq(%i[like notify_user spam])
      expect(visible_actions_for(post.user).sort).to eq([:like])
      expect(visible_actions_for(nil).sort).to eq([:like])
      expect(visible_actions_for(admin).sort).to eq(%i[like notify_user spam])
    end

    it "can't flag your own post to notify yourself" do
      serializer = PostSerializer.new(post, scope: Guardian.new(post.user), root: false)
      notify_user_action =
        serializer.actions_summary.find { |a| a[:id] == PostActionType.types[:notify_user] }
      expect(notify_user_action).to be_blank
    end

    it "should not allow user to flag post and notify non human user" do
      post.update!(user: Discourse.system_user)

      serializer = PostSerializer.new(post, scope: Guardian.new(actor), root: false)

      notify_user_action =
        serializer.actions_summary.find { |a| a[:id] == PostActionType.types[:notify_user] }

      expect(notify_user_action).to eq(nil)
    end
  end

  context "with a post with reviewable content" do
    let!(:reviewable) do
      PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post).reviewable
    end

    it "includes the reviewable data" do
      json =
        PostSerializer.new(post, scope: Guardian.new(Fabricate(:moderator)), root: false).as_json
      expect(json[:reviewable_id]).to eq(reviewable.id)
      expect(json[:reviewable_score_count]).to eq(1)
      expect(json[:reviewable_score_pending_count]).to eq(1)
    end
  end

  context "with a post by a nuked user" do
    subject(:serializer) do
      PostSerializer.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json
    end

    before { post.update!(user_id: nil, deleted_at: Time.zone.now) }

    it "serializes correctly" do
      %i[name username display_username avatar_template user_title trust_level].each do |attr|
        expect(serializer[attr]).to be_nil
      end
      %i[moderator staff yours].each { |attr| expect(serializer[attr]).to eq(false) }
    end
  end

  context "with a post by a suspended user" do
    def serializer
      PostSerializer.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json
    end

    it "serializes correctly" do
      expect(serializer[:user_suspended]).to be_nil

      post.user.update!(suspended_till: 1.month.from_now)

      expect(serializer[:user_suspended]).to eq(true)

      freeze_time(2.months.from_now)

      expect(serializer[:user_suspended]).to be_nil
    end
  end

  describe "#display_username" do
    let(:user) { post.user }
    let(:serializer) { PostSerializer.new(post, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "returns the display_username it when `enable_names` is on" do
      SiteSetting.enable_names = true
      expect(json[:display_username]).to be_present
    end

    it "doesn't return the display_username it when `enable_names` is off" do
      SiteSetting.enable_names = false
      expect(json[:display_username]).to be_blank
    end
  end

  context "with a hidden post with add_raw enabled" do
    let(:user) { Fabricate(:user) }
    let(:raw) { "Raw contents of the post." }

    context "with a public post" do
      let(:post) { Fabricate(:post, raw: raw, user: user) }

      it "includes the raw post for everyone" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          expect(serialized_post_for_user(user)[:raw]).to eq(raw)
        end
      end
    end

    context "with a hidden post" do
      let(:post) do
        Fabricate(
          :post,
          raw: raw,
          user: user,
          hidden: true,
          hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
        )
      end

      it "includes if the user can see it" do
        expect(serialized_post_for_user(Fabricate(:moderator))[:can_see_hidden_post]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:admin))[:can_see_hidden_post]).to eq(true)
        expect(serialized_post_for_user(user)[:can_see_hidden_post]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:user))[:can_see_hidden_post]).to eq(false)
      end

      it "shows the raw post only if authorized to see it" do
        expect(serialized_post_for_user(nil)[:raw]).to eq(nil)
        expect(serialized_post_for_user(Fabricate(:user))[:raw]).to eq(nil)

        expect(serialized_post_for_user(user)[:raw]).to eq(raw)
        expect(serialized_post_for_user(Fabricate(:moderator))[:raw]).to eq(raw)
        expect(serialized_post_for_user(Fabricate(:admin))[:raw]).to eq(raw)
      end

      it "can view edit history only if authorized" do
        expect(serialized_post_for_user(nil)[:can_view_edit_history]).to eq(false)
        expect(serialized_post_for_user(Fabricate(:user))[:can_view_edit_history]).to eq(false)

        expect(serialized_post_for_user(user)[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:moderator))[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:admin))[:can_view_edit_history]).to eq(true)
      end
    end

    context "with a hidden revised post" do
      fab!(:post) { Fabricate(:post, raw: "Hello world!", hidden: true) }

      before do
        SiteSetting.editing_grace_period_max_diff = 1

        revisor = PostRevisor.new(post)
        revisor.revise!(post.user, raw: "Hello, everyone!")
      end

      it "will not leak version to users" do
        json = PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
        expect(json[:version]).to eq(1)
      end

      it "will show real version to staff" do
        json = PostSerializer.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json
        expect(json[:version]).to eq(2)
      end
    end

    context "with a public wiki post" do
      let(:post) { Fabricate(:post, raw: raw, user: user, wiki: true) }

      it "can view edit history" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          expect(serialized_post_for_user(user)[:can_view_edit_history]).to eq(true)
        end
      end
    end

    context "with a hidden wiki post" do
      let(:post) do
        Fabricate(
          :post,
          raw: raw,
          user: user,
          wiki: true,
          hidden: true,
          hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
        )
      end

      it "can view edit history only if authorized" do
        expect(serialized_post_for_user(nil)[:can_view_edit_history]).to eq(false)
        expect(serialized_post_for_user(Fabricate(:user))[:can_view_edit_history]).to eq(false)
        expect(serialized_post_for_user(user)[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:moderator))[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:admin))[:can_view_edit_history]).to eq(true)
      end
    end
  end

  context "with a post with notices" do
    fab!(:user) { Fabricate(:user, trust_level: 1) }
    fab!(:user_tl1) { Fabricate(:user, trust_level: 1) }
    fab!(:user_tl2) { Fabricate(:user, trust_level: 2) }

    let(:post) do
      post = Fabricate(:post, user: user)
      post.custom_fields[Post::NOTICE] = {
        type: Post.notices[:returning_user],
        last_posted_at: 1.day.ago,
      }
      post.save_custom_fields
      post
    end

    def json_for_user(user)
      PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
    end

    it "is visible for TL2+ users (except poster)" do
      expect(json_for_user(nil)[:notice]).to eq(nil)
      expect(json_for_user(user)[:notice]).to eq(nil)

      SiteSetting.returning_user_notice_tl = 2
      expect(json_for_user(user_tl1)[:notice]).to eq(nil)
      expect(json_for_user(user_tl2)[:notice][:type]).to eq(Post.notices[:returning_user])

      SiteSetting.returning_user_notice_tl = 1
      expect(json_for_user(user_tl1)[:notice][:type]).to eq(Post.notices[:returning_user])
      expect(json_for_user(user_tl2)[:notice][:type]).to eq(Post.notices[:returning_user])
    end
  end

  context "with a post with bookmarks" do
    let(:current_user) { Fabricate(:user) }
    let(:topic_view) { TopicView.new(post.topic, current_user) }
    let(:serialized) do
      s = serialized_post(current_user)
      s.post_actions = PostAction.counts_for([post], current_user)[post.id]
      s.topic_view = topic_view
      s
    end

    context "when a Bookmark record exists for the user on the post" do
      let!(:bookmark) do
        Fabricate(:bookmark_next_business_day_reminder, user: current_user, bookmarkable: post)
      end

      context "with bookmarks with reminders" do
        it "returns true" do
          expect(serialized.as_json[:bookmarked]).to eq(true)
        end

        it "returns the reminder_at for the bookmark" do
          expect(serialized.as_json[:bookmark_reminder_at]).to eq(bookmark.reminder_at.iso8601)
        end
      end
    end
  end

  context "with posts when group moderation is enabled" do
    fab!(:topic)
    fab!(:group_user)
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:category_moderation_group) do
      Fabricate(:category_moderation_group, category: topic.category, group: group_user.group)
    end

    before { SiteSetting.enable_category_group_moderation = true }

    it "does nothing for regular users" do
      expect(serialized_post_for_user(nil)[:group_moderator]).to eq(nil)
    end

    it "returns a group_moderator attribute for category group moderators" do
      post.update!(user: group_user.user)
      expect(serialized_post_for_user(nil)[:group_moderator]).to eq(true)
    end
  end

  context "with a post with small action" do
    fab!(:post) { Fabricate(:small_action, action_code: "public_topic") }

    it "returns `action_code` based on `login_required` site setting" do
      expect(serialized_post_for_user(nil)[:action_code]).to eq("public_topic")
      SiteSetting.login_required = true
      expect(serialized_post_for_user(nil)[:action_code]).to eq("open_topic")
    end
  end

  context "with allow_anonymous_likes enabled" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post) { Fabricate(:post, topic: topic, user: topic.user) }
    fab!(:anonymous_user) { Fabricate(:anonymous) }

    let(:serializer) { PostSerializer.new(post, scope: Guardian.new(anonymous_user), root: false) }
    let(:post_action) do
      user.id = anonymous_user.id
      post.id = 1

      a =
        PostAction.new(
          user: anonymous_user,
          post: post,
          post_action_type_id: PostActionType.types[:like],
        )
      a.created_at = 1.minute.ago
      a
    end

    before do
      SiteSetting.allow_anonymous_posting = true
      SiteSetting.allow_anonymous_likes = true
      SiteSetting.post_undo_action_window_mins = 10
      PostSerializer.any_instance.stubs(:post_actions).returns({ 2 => post_action })
    end

    context "when post_undo_action_window_mins has not passed" do
      before { post_action.created_at = 5.minutes.ago }

      it "allows anonymous users to unlike posts" do
        like_actions_summary =
          serializer.actions_summary.find { |a| a[:id] == PostActionType.types[:like] }

        #When :can_act is present, the JavaScript allows the user to click the unlike button
        expect(like_actions_summary[:can_act]).to eq(true)
      end
    end

    context "when post_undo_action_window_mins has passed" do
      before { post_action.created_at = 20.minutes.ago }

      it "disallows anonymous users from unliking posts" do
        # There are no other post actions available to anonymous users so the action_summary will be an empty array
        expect(serializer.actions_summary.find { |a| a[:id] == PostActionType.types[:like] }).to eq(
          nil,
        )
      end
    end
  end

  context "with mentions" do
    fab!(:user_status)
    fab!(:user)

    let(:username) { "joffrey" }
    let(:user1) { Fabricate(:user, user_status: user_status, username: username) }
    let(:post) { Fabricate(:post, user: user, raw: "Hey @#{user1.username}") }
    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    context "when user status is enabled" do
      before { SiteSetting.enable_user_status = true }

      it "returns mentioned users with user status" do
        json = serializer.as_json
        expect(json[:mentioned_users]).to be_present
        expect(json[:mentioned_users].length).to be(1)
        expect(json[:mentioned_users][0]).to_not be_nil
        expect(json[:mentioned_users][0][:id]).to eq(user1.id)
        expect(json[:mentioned_users][0][:username]).to eq(user1.username)
        expect(json[:mentioned_users][0][:name]).to eq(user1.name)
        expect(json[:mentioned_users][0][:status][:description]).to eq(user_status.description)
        expect(json[:mentioned_users][0][:status][:emoji]).to eq(user_status.emoji)
      end

      context "when username has a capital letter" do
        let(:username) { "JoJo" }

        it "returns mentioned users with user status" do
          expect(serializer.as_json[:mentioned_users][0][:username]).to eq(user1.username)
        end
      end
    end

    context "when user status is disabled" do
      before { SiteSetting.enable_user_status = false }

      it "doesn't return mentioned users" do
        expect(serializer.as_json[:mentioned_users]).to be_nil
      end
    end
  end

  describe "#user_status" do
    fab!(:user_status)
    fab!(:user) { Fabricate(:user, user_status: user_status) }
    fab!(:post) { Fabricate(:post, user: user) }
    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    it "adds user status when enabled" do
      SiteSetting.enable_user_status = true

      json = serializer.as_json

      expect(json[:user_status]).to_not be_nil do |status|
        expect(status.description).to eq(user_status.description)
        expect(status.emoji).to eq(user_status.emoji)
      end
    end

    it "doesn't add user status when disabled" do
      SiteSetting.enable_user_status = false
      json = serializer.as_json
      expect(json.keys).not_to include :user_status
    end

    it "doesn't add status if user doesn't have it" do
      SiteSetting.enable_user_status = true

      user.clear_status!
      user.reload
      json = serializer.as_json

      expect(json.keys).not_to include :user_status
    end
  end

  describe "#badges_granted" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:badge1) do
      Badge.create!(
        name: "SomeBadge",
        badge_type_id: BadgeType::Bronze,
        show_posts: true,
        post_header: true,
      )
    end
    fab!(:badge2) do
      Badge.create!(
        name: "AnotherBadge",
        badge_type_id: BadgeType::Bronze,
        show_posts: true,
        post_header: true,
      )
    end
    fab!(:ub1) do
      UserBadge.create!(
        badge_id: badge1.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end
    fab!(:ub2) do
      UserBadge.create!(
        badge_id: badge2.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    it "doesn't include badges when `enable_badges` site setting is disabled" do
      SiteSetting.enable_badges = false
      expect(serializer.as_json[:badges_granted]).to eq([])
    end

    it "doesn't include badges when `show_badges_in_post_header` site setting is disabled" do
      SiteSetting.enable_badges = true
      SiteSetting.show_badges_in_post_header = false
      expect(serializer.as_json[:badges_granted]).to eq([])
    end

    it "includes badges when `enable_badges` and `show_badges_in_post_header` site settings are enabled" do
      SiteSetting.enable_badges = true
      SiteSetting.show_badges_in_post_header = true

      json = serializer.as_json

      expect(json[:badges_granted].length).to eq(2)
      expect(json[:badges_granted].map { |b| b[:badges][0][:id] }).to eq(
        [ub1.badge_id, ub2.badge_id],
      )
      expect(json[:badges_granted].map { |b| b[:basic_user_badge][:id] }).to eq([ub1.id, ub2.id])
    end
  end

  def serialized_post(u)
    s = PostSerializer.new(post, scope: Guardian.new(u), root: false)
    s.add_raw = true
    s
  end

  def serialized_post_for_user(u)
    s = serialized_post(u)
    s.as_json
  end
end
