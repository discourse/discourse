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

    it "updates users' topic and post counts" do
      p1user = p1.user
      p2user = p2.user
      topic.user_id = p1user.id
      topic.save!

      p1user.user_stat.update_attributes(topic_count: 1, post_count: 1)
      p2user.user_stat.update_attributes(topic_count: 0, post_count: 1)

      described_class.new(post_ids: [p1.id, p2.id], topic_id: topic.id, new_owner: user_a, acting_user: editor).change_owner!

      p1user.reload; p2user.reload; user_a.reload
      p1user.topic_count.should == 0
      p1user.post_count.should == 0
      p2user.topic_count.should == 0
      p2user.post_count.should == 0
      user_a.topic_count.should == 1
      user_a.post_count.should == 2
    end
  end
end
