require "rails_helper"

describe PostOwnerChanger do
  describe "change_owner!" do
    let!(:editor) { Fabricate(:admin) }
    let(:topic) { Fabricate(:topic) }
    let(:user_a) { Fabricate(:user) }
    let(:p1) { Fabricate(:post, topic: topic, post_number: 1) }
    let(:p2) { Fabricate(:post, topic: topic, post_number: 2) }
    let(:p3) { Fabricate(:post) }

    it "raises an error with a parameter missing" do
      expect {
        PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: nil, acting_user: editor)
      }.to raise_error(ArgumentError)
    end

    it "calls PostRevisor" do
      PostRevisor.any_instance.expects(:revise!)
      PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
    end

    it "changes the user" do
      bumped_at = topic.bumped_at

      freeze_time 2.days.from_now

      old_user = p1.user
      PostAction.act(user_a, p1, PostActionType.types[:like])
      p1.reload
      expect(p1.topic.like_count).to eq(1)
      PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      p1.reload
      expect(p1.topic.like_count).to eq(0)
      expect(p1.topic.bumped_at).to be_within(1.second).of (bumped_at)
      expect(p1.topic.last_post_user_id).to eq(user_a.id)
      expect(old_user).not_to eq(p1.user)
      expect(p1.user).to eq(user_a)
    end

    it "changes multiple posts" do
      PostOwnerChanger.new(post_ids: [p1.id, p2.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      p1.reload; p2.reload
      expect(p1.user).not_to eq(nil)
      expect(p1.user).to eq(user_a)
      expect(p1.user).to eq(p2.user)
    end

    it "ignores posts in other topics" do
      PostOwnerChanger.new(post_ids: [p1.id, p3.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      p1.reload; p3.reload
      expect(p1.user).to eq(user_a)

      expect(p3.topic_id).not_to eq(p1.topic_id)
      expect(p2.user).not_to eq(user_a)
    end

    it "skips creating new post revision if skip_revision is true" do
      PostOwnerChanger.new(post_ids: [p1.id, p2.id], topic_id: topic.id, new_owner: user_a, acting_user: editor, skip_revision: true).change_owner!
      p1.reload; p2.reload
      expect(p1.revisions.size).to eq(0)
      expect(p2.revisions.size).to eq(0)
    end

    it "changes the user even when the post does not pass validation" do
      p1.update_attribute(:raw, "foo")
      PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      expect(p1.reload.user).to eq(user_a)
    end

    it "changes the user even when the topic does not pass validation" do
      topic.update_column(:title, "short")

      PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      expect(p1.reload.user).to eq(user_a)
    end

    it "changes the owner when the post is deleted" do
      p4 = Fabricate(:post, topic: topic, reply_to_post_number: p2.post_number)
      PostDestroyer.new(editor, p4).destroy

      PostOwnerChanger.new(post_ids: [p4.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      expect(p4.reload.user).to eq(user_a)
    end

    context "sets topic notification level for the new owner" do
      let(:p4) { Fabricate(:post, post_number: 2, topic: topic) }

      it "'watching' if the first post gets a new owner" do
        PostOwnerChanger.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
        tu = TopicUser.find_by(user_id: user_a.id, topic_id: topic.id)
        expect(tu.notification_level).to eq(3)
      end

      it "'tracking' if other than the first post gets a new owner" do
        PostOwnerChanger.new(post_ids: [p4.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
        tu = TopicUser.find_by(user_id: user_a.id, topic_id: topic.id)
        expect(tu.notification_level).to eq(2)
      end
    end

    context "integration tests" do
      let(:p1user) { p1.user }
      let(:p2user) { p2.user }

      before do
        topic.update!(user_id: p1user.id)

        p1user.user_stat.update!(
          topic_count: 1,
          post_count: 1,
          first_post_created_at: p1.created_at,
          topic_reply_count: 0
        )

        p2user.user_stat.update!(
          topic_count: 0,
          post_count: 1,
          first_post_created_at: p2.created_at,
          topic_reply_count: 1
        )

        UserAction.create!(action_type: UserAction::NEW_TOPIC, user_id: p1user.id, acting_user_id: p1user.id,
                           target_post_id: -1, target_topic_id: p1.topic_id, created_at: p1.created_at)
        UserAction.create!(action_type: UserAction::REPLY, user_id: p2user.id, acting_user_id: p2user.id,
                           target_post_id: p2.id, target_topic_id: p2.topic_id, created_at: p2.created_at)

        UserActionCreator.enable
      end

      subject(:change_owners) do
        PostOwnerChanger.new(
          post_ids: [p1.id, p2.id],
          topic_id: topic.id,
          new_owner: user_a,
          acting_user: editor
        ).change_owner!
      end

      it "updates users' topic and post counts" do
        PostAction.act(p2user, p1, PostActionType.types[:like])
        expect(p1user.user_stat.reload.likes_received).to eq(1)

        change_owners

        p1user.reload; p2user.reload; user_a.reload
        expect(p1user.topic_count).to eq(0)
        expect(p1user.post_count).to eq(0)
        expect(p2user.topic_count).to eq(0)
        expect(p2user.post_count).to eq(0)
        expect(user_a.topic_count).to eq(1)
        expect(user_a.post_count).to eq(2)

        p1_user_stat = p1user.user_stat

        expect(p1_user_stat.first_post_created_at).to eq(nil)
        expect(p1_user_stat.topic_reply_count).to eq(0)
        expect(p1_user_stat.likes_received).to eq(0)

        p2_user_stat = p2user.user_stat

        expect(p2_user_stat.first_post_created_at).to eq(nil)
        expect(p2_user_stat.topic_reply_count).to eq(0)

        user_a_stat = user_a.user_stat

        expect(user_a_stat.first_post_created_at).to be_present
        expect(user_a_stat.likes_received).to eq(1)
      end

      it "handles whispers" do
        whisper = PostCreator.new(
          editor,
          topic_id: p1.topic_id,
          reply_to_post_number: 1,
          post_type: Post.types[:whisper],
          raw: 'this is a whispered reply'
        ).create

        user_stat = editor.user_stat

        expect {
          PostOwnerChanger.new(
            post_ids: [whisper.id],
            topic_id: topic.id,
            new_owner: Fabricate(:admin),
            acting_user: editor
          ).change_owner!
        }.to_not change { user_stat.reload.post_count }
      end

      context 'private message topic' do
        let(:topic) { Fabricate(:private_message_topic) }

        it "should update users' counts" do
          PostAction.act(p2user, p1, PostActionType.types[:like])

          expect {
            change_owners
          }.to_not change { p1user.user_stat.post_count }

          expect(p1user.user_stat.likes_received).to eq(0)

          user_a_stat = user_a.user_stat
          expect(user_a_stat.first_post_created_at).to be_present
          expect(user_a_stat.likes_received).to eq(0)
          expect(user_a_stat.post_count).to eq(0)
        end
      end

      it "updates UserAction records" do
        g = Guardian.new(editor)
        expect(UserAction.stats(user_a.id, g)).to eq([])

        change_owners

        expect(UserAction.stats(p1user.id, g)).to eq([])
        expect(UserAction.stats(p2user.id, g)).to eq([])
        stats = UserAction.stats(user_a.id, g)
        expect(stats.size).to eq(2)
        expect(stats[0].action_type).to eq(UserAction::NEW_TOPIC)
        expect(stats[0].count).to eq(1)
        expect(stats[1].action_type).to eq(UserAction::REPLY)
        expect(stats[1].count).to eq(1)
      end
    end
  end
end
