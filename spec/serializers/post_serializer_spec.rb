# frozen_string_literal: true

require 'rails_helper'

describe PostSerializer do
  fab!(:post) { Fabricate(:post) }

  context "a post with lots of actions" do
    fab!(:actor) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }
    let(:acted_ids) {
      PostActionType.public_types.values
        .concat([:notify_user, :spam].map { |k| PostActionType.types[k] })
    }

    def visible_actions_for(user)
      serializer = PostSerializer.new(post, scope: Guardian.new(user), root: false)
      # NOTE this is messy, we should extract all this logic elsewhere
      serializer.post_actions = PostAction.counts_for([post], actor)[post.id] if user.try(:id) == actor.id
      actions = serializer.as_json[:actions_summary]
      lookup = PostActionType.types.invert
      actions.keep_if { |a| (a[:count] || 0) > 0 }.map { |a| lookup[a[:id]] }
    end

    before do
      acted_ids.each do |id|
        PostActionCreator.new(actor, post, id).perform
      end
      post.reload
    end

    it "displays the correct info" do
      expect(visible_actions_for(actor).sort).to eq([:like, :notify_user, :spam])
      expect(visible_actions_for(post.user).sort).to eq([:like])
      expect(visible_actions_for(nil).sort).to eq([:like])
      expect(visible_actions_for(admin).sort).to eq([:like, :notify_user, :spam])
    end

    it "can't flag your own post to notify yourself" do
      serializer = PostSerializer.new(post, scope: Guardian.new(post.user), root: false)
      notify_user_action = serializer.actions_summary.find { |a| a[:id] == PostActionType.types[:notify_user] }
      expect(notify_user_action).to be_blank
    end

    it "should not allow user to flag post and notify non human user" do
      post.update!(user: Discourse.system_user)

      serializer = PostSerializer.new(post,
        scope: Guardian.new(actor),
        root: false
      )

      notify_user_action = serializer.actions_summary.find do |a|
        a[:id] == PostActionType.types[:notify_user]
      end

      expect(notify_user_action).to eq(nil)
    end
  end

  context "a post with reviewable content" do
    let!(:reviewable) { PostActionCreator.spam(Fabricate(:user), post).reviewable }

    it "includes the reviewable data" do
      json = PostSerializer.new(post, scope: Guardian.new(Fabricate(:moderator)), root: false).as_json
      expect(json[:reviewable_id]).to eq(reviewable.id)
      expect(json[:reviewable_score_count]).to eq(1)
      expect(json[:reviewable_score_pending_count]).to eq(1)
    end
  end

  context "a post by a nuked user" do
    before do
      post.update!(
        user_id: nil,
        deleted_at: Time.zone.now
      )
    end

    subject { PostSerializer.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json }

    it "serializes correctly" do
      [:name, :username, :display_username, :avatar_template, :user_title, :trust_level].each do |attr|
        expect(subject[attr]).to be_nil
      end
      [:moderator, :staff, :yours].each do |attr|
        expect(subject[attr]).to eq(false)
      end
    end
  end

  context "display_username" do
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

  context "a hidden post with add_raw enabled" do
    let(:user) { Fabricate.build(:user, id: 101) }
    let(:raw)  { "Raw contents of the post." }

    context "a public post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user) }

      it "includes the raw post for everyone" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          expect(serialized_post_for_user(user)[:raw]).to eq(raw)
        end
      end
    end

    context "a hidden post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached]) }

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

    context "a hidden revised post" do
      fab!(:post) { Fabricate(:post, raw: 'Hello world!', hidden: true) }

      before do
        SiteSetting.editing_grace_period_max_diff = 1

        revisor = PostRevisor.new(post)
        revisor.revise!(post.user, raw: 'Hello, everyone!')
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

    context "a public wiki post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user, wiki: true) }

      it "can view edit history" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          expect(serialized_post_for_user(user)[:can_view_edit_history]).to eq(true)
        end
      end
    end

    context "a hidden wiki post" do
      let(:post) {
        Fabricate.build(
          :post,
          raw: raw,
          user: user,
          wiki: true,
          hidden: true,
          hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached])
      }

      it "can view edit history only if authorized" do
        expect(serialized_post_for_user(nil)[:can_view_edit_history]).to eq(false)
        expect(serialized_post_for_user(Fabricate(:user))[:can_view_edit_history]).to eq(false)
        expect(serialized_post_for_user(user)[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:moderator))[:can_view_edit_history]).to eq(true)
        expect(serialized_post_for_user(Fabricate(:admin))[:can_view_edit_history]).to eq(true)
      end
    end

  end

  context "a post with notices" do
    fab!(:user) { Fabricate(:user, trust_level: 1) }
    fab!(:user_tl1) { Fabricate(:user, trust_level: 1) }
    fab!(:user_tl2) { Fabricate(:user, trust_level: 2) }

    let(:post) {
      post = Fabricate(:post, user: user)
      post.custom_fields[Post::NOTICE_TYPE] = Post.notices[:returning_user]
      post.custom_fields[Post::NOTICE_ARGS] = 1.day.ago
      post.save_custom_fields
      post
    }

    def json_for_user(user)
      PostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
    end

    it "is visible for TL2+ users (except poster)" do
      expect(json_for_user(nil)[:notice_type]).to eq(nil)
      expect(json_for_user(user)[:notice_type]).to eq(nil)

      SiteSetting.returning_user_notice_tl = 2
      expect(json_for_user(user_tl1)[:notice_type]).to eq(nil)
      expect(json_for_user(user_tl2)[:notice_type]).to eq(Post.notices[:returning_user])

      SiteSetting.returning_user_notice_tl = 1
      expect(json_for_user(user_tl1)[:notice_type]).to eq(Post.notices[:returning_user])
      expect(json_for_user(user_tl2)[:notice_type]).to eq(Post.notices[:returning_user])
    end
  end

  context "post with bookmarks" do
    let(:current_user) { Fabricate(:user) }
    let(:topic_view) { TopicView.new(post.topic, current_user) }
    let(:serialized) do
      s = serialized_post(current_user)
      s.post_actions = PostAction.counts_for([post], current_user)[post.id]
      s.topic_view = topic_view
      s
    end

    context "when a user post action for the bookmark exists" do
      before do
        PostActionCreator.create(current_user, post, :bookmark)
      end

      it "returns true" do
        expect(serialized.as_json[:bookmarked]).to eq(true)
      end
    end

    context "when a user post action for the bookmark does not exist" do
      it "does not return the bookmarked attribute" do
        expect(serialized.as_json.key?(:bookmarked)).to eq(false)
      end
    end

    context "when a Bookmark record exists for the user on the post" do
      let!(:bookmark) { Fabricate(:bookmark_next_business_day_reminder, user: current_user, post: post) }

      context "when the site setting for bookmarks with reminders is enabled" do
        before do
          SiteSetting.enable_bookmarks_with_reminders = true
        end

        it "returns true" do
          expect(serialized.as_json[:bookmarked_with_reminder]).to eq(true)
        end

        it "returns the reminder_at for the bookmark" do
          expect(serialized.as_json[:bookmark_reminder_at]).to eq(bookmark.reminder_at.iso8601)
        end

        context "if topic_view is blank" do
          let(:topic_view) { nil }

          it "does not return the bookmarked_with_reminder attribute" do
            expect(serialized.as_json.key?(:bookmarked_with_reminder)).to eq(false)
          end
        end
      end

      context "when the site setting for bookmarks with reminders is disabled" do
        it "does not return the bookmarked_with_reminder attribute" do
          expect(serialized.as_json.key?(:bookmarked_with_reminder)).to eq(false)
        end

        it "does not return the bookmark_reminder_at attribute" do
          expect(serialized.as_json.key?(:bookmark_reminder_at)).to eq(false)
        end
      end
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
