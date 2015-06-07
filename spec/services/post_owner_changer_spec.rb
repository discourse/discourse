require "spec_helper"

describe PostOwnerChanger do
  describe "change_owner!" do
    let!(:editor) { Fabricate(:admin) }
    let(:topic) { Fabricate(:topic) }
    let(:user_a) { Fabricate(:user) }
    let(:p1) { Fabricate(:post, topic_id: topic.id) }
    let(:p2) { Fabricate(:post, topic_id: topic.id) }

    it "raises an error with a parameter missing" do
      expect {
        described_class.new(post_ids: [p1.id], topic_id: topic.id, new_owner: nil, acting_user: editor)
      }.to raise_error(ArgumentError)
    end

    it "calls PostRevisor" do
      PostRevisor.any_instance.expects(:revise!)
      described_class.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
    end

    it "changes the user" do
      old_user = p1.user
      described_class.new(post_ids: [p1.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      p1.reload
      expect(old_user).not_to eq(p1.user)
      expect(p1.user).to eq(user_a)
    end

    it "changes multiple posts" do
      described_class.new(post_ids: [p1.id, p2.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!
      p1.reload; p2.reload
      expect(p1.user).not_to eq(nil)
      expect(p1.user).to eq(user_a)
      expect(p1.user).to eq(p2.user)
    end

    context "integration tests" do
      let(:p1user) { p1.user }
      let(:p2user) { p2.user }

      before do
        topic.user_id = p1user.id
        topic.save!

        p1user.user_stat.update_attributes(topic_count: 1, post_count: 1, first_post_created_at: p1.created_at, topic_reply_count: 0)
        p2user.user_stat.update_attributes(topic_count: 0, post_count: 1, first_post_created_at: p2.created_at, topic_reply_count: 1)

        UserAction.create!( action_type: UserAction::NEW_TOPIC, user_id: p1user.id, acting_user_id: p1user.id,
                            target_post_id: -1, target_topic_id: p1.topic_id, created_at: p1.created_at )
        UserAction.create!( action_type: UserAction::REPLY, user_id: p2user.id, acting_user_id: p2user.id,
                            target_post_id: p2.id, target_topic_id: p2.topic_id, created_at: p2.created_at )

        ActiveRecord::Base.observers.enable :user_action_observer
      end

      subject(:change_owners) { described_class.new(post_ids: [p1.id, p2.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner! }

      it "updates users' topic and post counts" do
        change_owners

        p1user.reload; p2user.reload; user_a.reload
        expect(p1user.topic_count).to eq(0)
        expect(p1user.post_count).to eq(0)
        expect(p2user.topic_count).to eq(0)
        expect(p2user.post_count).to eq(0)
        expect(user_a.topic_count).to eq(1)
        expect(user_a.post_count).to eq(2)
        expect(p1user.user_stat.first_post_created_at).to eq(nil)
        expect(p2user.user_stat.first_post_created_at).to eq(nil)
        expect(p1user.user_stat.topic_reply_count).to eq(0)
        expect(p2user.user_stat.topic_reply_count).to eq(0)
        expect(user_a.user_stat.first_post_created_at).to be_present
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
