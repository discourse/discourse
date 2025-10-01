# frozen_string_literal: true

RSpec.describe ReviewableFlagHandling do
  fab!(:admin)
  fab!(:user)
  fab!(:moderator)

  describe "flag handling methods" do
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:reviewable) { PostActionCreator.spam(admin, post).reviewable }

    describe "#agree_with_flags" do
      it "marks all flags as agreed and triggers events" do
        flag_action = PostAction.active.where(post_id: post.id).first
        expect(flag_action.agreed_at).to be_nil

        events = DiscourseEvent.track_events { reviewable.send(:agree_with_flags, moderator, {}) }

        expect(flag_action.reload.agreed_at).to be_present
        expect(flag_action.agreed_by_id).to eq(moderator.id)

        expect(events.map { |e| e[:event_name] }).to contain_exactly(
          :flag_reviewed,
          :flag_agreed,
          :confirmed_spam_post,
        )
      end

      it "triggers spam event for spam flags" do
        events = DiscourseEvent.track_events { reviewable.send(:agree_with_flags, moderator, {}) }

        expect(events.map { |e| e[:event_name] }).to include(:confirmed_spam_post)
      end

      it "yields first action to block if given" do
        yielded_action = nil
        reviewable.send(:agree_with_flags, moderator, {}) { |action| yielded_action = action }

        expect(yielded_action).to be_a(PostAction)
        expect(yielded_action.agreed_at).to be_present
      end

      it "returns array of flagging user IDs" do
        user_ids = reviewable.send(:agree_with_flags, moderator, {})

        expect(user_ids).to eq([admin.id])
      end
    end

    describe "#disagree_with_flags" do
      it "marks all flags as disagreed and triggers events" do
        flag_action = PostAction.active.where(post_id: post.id).first

        events =
          DiscourseEvent.track_events { reviewable.send(:disagree_with_flags, moderator, {}) }

        expect(flag_action.reload.disagreed_at).to be_present
        expect(flag_action.disagreed_by_id).to eq(moderator.id)

        expect(events.map { |e| e[:event_name] }).to contain_exactly(
          :flag_reviewed,
          :flag_disagreed,
        )
      end

      it "resets flag counters on the post" do
        post.update!(spam_count: 5)

        reviewable.send(:disagree_with_flags, moderator, {})

        expect(post.reload.spam_count).to eq(0)
      end

      it "unhides post if hidden" do
        post.update!(hidden: true, hidden_at: Time.zone.now)

        reviewable.send(:disagree_with_flags, moderator, {})

        expect(post.reload.hidden?).to be(false)
      end

      it "returns array of flagging user IDs" do
        user_ids = reviewable.send(:disagree_with_flags, moderator, {})

        expect(user_ids).to eq([admin.id])
      end
    end

    describe "#ignore_flags" do
      it "marks all flags as deferred and triggers events" do
        flag_action = PostAction.active.where(post_id: post.id).first

        events = DiscourseEvent.track_events { reviewable.send(:ignore_flags, moderator, {}) }

        expect(flag_action.reload.deferred_at).to be_present
        expect(flag_action.deferred_by_id).to eq(moderator.id)

        expect(events.map { |e| e[:event_name] }).to contain_exactly(:flag_reviewed, :flag_deferred)
      end

      it "returns array of flagging user IDs" do
        user_ids = reviewable.send(:ignore_flags, moderator, {})

        expect(user_ids).to eq([admin.id])
      end
    end
  end
end
