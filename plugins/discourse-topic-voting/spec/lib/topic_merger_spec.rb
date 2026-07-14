# frozen_string_literal: true

describe DiscourseTopicVoting::TopicMerger do
  fab!(:user_0, :user)
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:user_4, :user)
  fab!(:user_5, :user)

  fab!(:category_1, :category)
  fab!(:category_2, :category)

  fab!(:topic_0) { Fabricate(:topic, category: category_1) }
  fab!(:topic_1) { Fabricate(:topic, category: category_2) }

  before { SiteSetting.topic_voting_enabled = true }

  describe ".merge" do
    it "does nothing when the source topic is still open" do
      DiscourseTopicVoting::Vote.create!(user: user_0, topic: topic_0)
      topic_0.update_vote_count

      described_class.merge(topic_0, topic_1)

      user_0.reload
      expect(user_0.topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_0.id)
      expect(user_0.topics_with_archived_vote.pluck(:topic_id)).to be_blank
    end

    it "archives moved votes when the destination topic is closed" do
      topic_0.update_status("closed", true, Discourse.system_user)
      topic_1.update_status("closed", true, Discourse.system_user)

      DiscourseTopicVoting::Vote.create!(user: user_0, topic: topic_0)
      topic_0.update_vote_count

      described_class.merge(topic_0, topic_1)

      user_0.reload
      expect(user_0.topics_with_vote.pluck(:topic_id)).to be_blank
      expect(user_0.topics_with_archived_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(topic_0.reload.vote_count).to eq(0)
      expect(topic_1.reload.vote_count).to eq(1)
    end

    it "enqueues the backfill badges job for the destination topic when votes move" do
      topic_0.update_status("closed", true, Discourse.system_user)

      DiscourseTopicVoting::Vote.create!(user: user_0, topic: topic_0)
      topic_0.update_vote_count

      expect { described_class.merge(topic_0, topic_1) }.to change(
        Jobs::DiscourseTopicVoting::BackfillBadges.jobs,
        :size,
      ).by(1)
      expect(Jobs::DiscourseTopicVoting::BackfillBadges.jobs.last["args"].first).to include(
        "topic_id" => topic_1.id,
      )
    end
  end

  context "when merging topics via move_posts (topic_merged)" do
    let(:users) { [user_0, user_1, user_2, user_3, user_4, user_5] }

    before do
      SiteSetting.topic_voting_show_who_voted = false

      Fabricate(:post, topic: topic_0, user: user_0)
      Fabricate(:post, topic: topic_0, user: user_0)

      DiscourseTopicVoting::Vote.create!(user: users[0], topic: topic_0)
      DiscourseTopicVoting::Vote.create!(user: users[1], topic: topic_1)
      DiscourseTopicVoting::Vote.create!(user: users[2], topic: topic_0)
      DiscourseTopicVoting::Vote.create!(user: users[2], topic: topic_1)
      DiscourseTopicVoting::Vote.create!(user: users[4], topic: topic_0, archive: true)
      DiscourseTopicVoting::Vote.create!(user: users[5], topic: topic_0, archive: true)
      DiscourseTopicVoting::Vote.create!(user: users[5], topic: topic_1)

      [topic_0, topic_1].each { |t| t.update_vote_count }
    end

    it "moves votes when entire topic is merged" do
      topic_0.move_posts(
        Discourse.system_user,
        topic_0.posts.pluck(:id),
        destination_topic_id: topic_1.id,
      )

      users.each { |user| user.reload }
      expect(users[0].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[0].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[1].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[1].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[2].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[2].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[3].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[4].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[4].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[5].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[5].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(topic_0.reload.vote_count).to eq(0)
      expect(topic_1.reload.vote_count).to eq(5)

      merged_post = topic_0.posts.find_by(action_code: "split_topic")
      expect(merged_post.raw).to include(I18n.t("topic_voting.votes_moved", count: 2))
      expect(merged_post.raw).to include(I18n.t("topic_voting.duplicated_votes", count: 2))
    end

    it "does not move votes when not all posts are moved and the original topic does not get closed" do
      topic_0.move_posts(
        Discourse.system_user,
        [topic_0.posts.order(:post_number).first.id],
        destination_topic_id: topic_1.id,
      )

      users.each { |user| user.reload }
      expect(users[0].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_0.id)
      expect(users[0].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[1].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_1.id)
      expect(users[1].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[2].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic_0.id, topic_1.id)
      expect(users[2].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[4].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[4].topics_with_archived_vote.pluck(:topic_id)).to contain_exactly(topic_0.id)

      expect(topic_0.reload.vote_count).to eq(4)
      expect(topic_1.reload.vote_count).to eq(3)
    end
  end
end
