# frozen_string_literal: true

describe DiscourseTopicVoting do
  let!(:user0) { Fabricate(:user) }
  let!(:user1) { Fabricate(:user) }
  let!(:user2) { Fabricate(:user) }
  let!(:user3) { Fabricate(:user) }
  let!(:user4) { Fabricate(:user) }
  let!(:user5) { Fabricate(:user) }

  let(:category1) { Fabricate(:category) }
  let(:category2) { Fabricate(:category) }

  let!(:topic0) { Fabricate(:topic, category: category1) }
  let!(:topic1) { Fabricate(:topic, category: category2) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.topic_voting_show_who_voted = true
  end

  it "doesn't allow users to vote more than they are allowed" do
    SiteSetting.topic_voting_tl1_vote_limit = 1
    user0.update!(trust_level: 1)

    expect(user0.reached_voting_limit?).to eq(false)

    DiscourseTopicVoting::Vote.create!(user: user0, topic: topic0)

    expect(user0.reached_voting_limit?).to eq(true)
  end

  it "doesn't allow users to vote if their trust level vote limit is 0" do
    SiteSetting.topic_voting_tl1_vote_limit = 0
    user0.update!(trust_level: 1)

    expect(user0.vote_limit_0?).to eq(true)
    expect(user0.reached_voting_limit?).to eq(true)
  end

  context "with two topics" do
    let(:users) { [user0, user1, user2, user3, user4, user5] }

    before do
      # ensure merging votes works regardless of voters' visibility
      SiteSetting.topic_voting_show_who_voted = false

      Fabricate(:post, topic: topic0, user: user0)
      Fabricate(:post, topic: topic0, user: user0)

      # +user0+ votes +topic0+, +user1+ votes +topic1+ and +user2+ votes both
      # topics.
      DiscourseTopicVoting::Vote.create!(user: users[0], topic: topic0)
      DiscourseTopicVoting::Vote.create!(user: users[1], topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: users[2], topic: topic0)
      DiscourseTopicVoting::Vote.create!(user: users[2], topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: users[4], topic: topic0, archive: true)
      DiscourseTopicVoting::Vote.create!(user: users[5], topic: topic0, archive: true)
      DiscourseTopicVoting::Vote.create!(user: users[5], topic: topic1)

      [topic0, topic1].each { |t| t.update_vote_count }
    end

    it "moves votes when entire topic is merged" do
      topic0.move_posts(
        Discourse.system_user,
        topic0.posts.pluck(:id),
        destination_topic_id: topic1.id,
      )

      users.each { |user| user.reload }
      expect(users[0].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[0].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[1].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[1].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[2].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[2].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[3].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[4].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[4].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(users[5].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[5].topics_with_archived_vote.pluck(:topic_id)).to be_blank

      expect(topic0.reload.vote_count).to eq(0)
      expect(topic1.reload.vote_count).to eq(5)

      merged_post = topic0.posts.find_by(action_code: "split_topic")
      expect(merged_post.raw).to include(I18n.t("topic_voting.votes_moved", count: 2))
      expect(merged_post.raw).to include(I18n.t("topic_voting.duplicated_votes", count: 2))
    end

    it "does not move votes when not all posts are moved and the original topic does not get closed" do
      topic0.move_posts(
        Discourse.system_user,
        [topic0.posts.order(:post_number).first.id],
        destination_topic_id: topic1.id,
      )

      users.each { |user| user.reload }
      expect(users[0].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic0.id)
      expect(users[0].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[1].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(users[1].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[2].topics_with_vote.pluck(:topic_id)).to contain_exactly(topic0.id, topic1.id)
      expect(users[2].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[3].topics_with_archived_vote.pluck(:topic_id)).to be_blank
      expect(users[4].topics_with_vote.pluck(:topic_id)).to be_blank
      expect(users[4].topics_with_archived_vote.pluck(:topic_id)).to contain_exactly(topic0.id)

      expect(topic0.reload.vote_count).to eq(4)
      expect(topic1.reload.vote_count).to eq(3)
    end
  end

  context "when a user has an empty string as the votes custom field" do
    before { user0.votes.delete_all }

    it "returns a vote count of zero" do
      expect(user0.vote_count).to eq(0)
      expect(user0.topics_with_archived_vote.pluck(:topic_id)).to eq([])
    end
  end

  context "when topic status is changed" do
    it "enqueues a job for releasing/reclaiming votes" do
      blk = Proc.new { |topic| expect(topic).to be_instance_of(Topic) }
      DiscourseEvent.on(:topic_status_updated, &blk)

      topic1.update_status("closed", true, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.first["args"].first["topic_id"]).to eq(
        topic1.id,
      )

      topic1.update_status("closed", false, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.first["args"].first["topic_id"]).to eq(
        topic1.id,
      )
    ensure
      DiscourseEvent.off(:topic_status_updated, &blk)
    end

    it "doesn't enqueue a job for reclaiming votes if the topic is deleted" do
      topic1.update_status("closed", true, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.first["args"].first["topic_id"]).to eq(
        topic1.id,
      )

      topic1.trash!

      topic1.update_status("closed", false, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "doesn't enqueue a job for reclaiming votes when opening an archived topic" do
      topic1.update_status("closed", true, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.first["args"].first["topic_id"]).to eq(
        topic1.id,
      )

      topic1.update_status("archived", true, Discourse.system_user)

      topic1.update_status("closed", false, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "doesn't enqueue a job for reclaiming votes when un-archiving a closed topic" do
      topic1.update_status("archived", true, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.first["args"].first["topic_id"]).to eq(
        topic1.id,
      )

      topic1.update_status("closed", true, Discourse.system_user)

      topic1.update_status("archived", false, Discourse.system_user)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "creates notification that topic was completed" do
      Jobs.run_immediately!
      DiscourseTopicVoting::Vote.create!(user: user0, topic: topic1)
      expect { topic1.update_status("closed", true, user0) }.to change {
        user0.reload.notifications.count
      }.by(1)
      notification = user0.notifications.last
      expect(notification.topic_id).to eq(topic1.id)
      expect(JSON.parse(notification.data)["message"]).to eq("votes_released")
    end
  end

  context "when a topic is trashed and then recovered" do
    it "released the vote back to the user, then reclaims it on topic recovery" do
      Jobs.run_immediately!
      DiscourseTopicVoting::Vote.create!(user: user0, topic: topic1)

      topic1.reload.trash!
      expect(user0.reload.topics_with_vote.pluck(:topic_id)).to eq([])
      expect(user0.notifications.count).to eq(0)

      topic1.recover!
      expect(user0.reload.topics_with_vote.pluck(:topic_id)).to eq([topic1.id])
    end
  end

  context "when a topic is moved to a category" do
    let(:admin) { Fabricate(:admin) }
    let(:post0) { Fabricate(:post, topic: topic0, post_number: 1) }
    let(:post1) { Fabricate(:post, topic: topic1, post_number: 1) }

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: category1)
      category1.save!
      Category.reset_voting_cache
    end

    it "enqueues a job to reclaim votes if voting is enabled for the new category" do
      user = post1.user
      DiscourseTopicVoting::Vote.create!(user: user, topic: post1.topic, archive: true)
      DiscourseTopicVoting::Vote.create!(user: user, topic_id: 456_456, archive: true)

      PostRevisor.new(post1).revise!(admin, category_id: category1.id)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.first["args"].first["topic_id"]).to eq(
        post1.reload.topic_id,
      )

      Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: post1.topic_id)
      user.reload

      expect(user.topics_with_vote.pluck(:topic_id)).to eq([post1.topic_id])
      expect(user.topics_with_archived_vote.pluck(:topic_id)).to eq([456_456])
    end

    it "doesn't enqueue a job to reclaim votes if category not changed" do
      user = post1.user
      DiscourseTopicVoting::Vote.create!(user: user, topic: post0.topic, archive: true)
      DiscourseTopicVoting::Vote.create!(user: user, topic_id: 456_456, archive: true)

      PostRevisor.new(post0).revise!(admin, title: "Updated #{post0.topic.title}")
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "doesn't enqueue a job to reclaim votes if topic is closed" do
      DiscourseTopicVoting::Vote.create!(user: post1.user, topic: post1.topic, archive: true)
      post1.topic.update_status("closed", true, Discourse.system_user)
      PostRevisor.new(post1).revise!(admin, category_id: category1.id)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "doesn't enqueue a job to reclaim votes if topic is archived" do
      DiscourseTopicVoting::Vote.create!(user: post1.user, topic: post1.topic, archive: true)
      post1.topic.update_status("archived", true, Discourse.system_user)
      PostRevisor.new(post1).revise!(admin, category_id: category1.id)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "doesn't enqueue a job to reclaim votes if topic is trashed" do
      DiscourseTopicVoting::Vote.create!(user: post1.user, topic: post1.topic, archive: true)
      post1.topic.trash!
      PostRevisor.new(post1).revise!(admin, category_id: category1.id)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.length).to eq(0)
    end

    it "enqueues a job to release votes if voting is disabled for the new category" do
      user = post0.user
      DiscourseTopicVoting::Vote.create!(user: user, topic: post0.topic)
      DiscourseTopicVoting::Vote.create!(user: user, topic_id: 456_456)

      PostRevisor.new(post0).revise!(admin, category_id: category2.id)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.first["args"].first["topic_id"]).to eq(
        post0.reload.topic_id,
      )

      Jobs::DiscourseTopicVoting::VoteRelease.new.execute(topic_id: post0.topic_id)
      user.reload

      expect(user.topics_with_archived_vote.pluck(:topic_id)).to eq([post0.topic_id])
      expect(user.topics_with_vote.pluck(:topic_id)).to eq([456_456])
    end

    it "doesn't enqueue a job if the topic has no votes" do
      PostRevisor.new(post0).revise!(admin, category_id: category2.id)
      expect(Jobs::DiscourseTopicVoting::VoteRelease.jobs.size).to eq(0)

      PostRevisor.new(post1).revise!(admin, category_id: category1.id)
      expect(Jobs::DiscourseTopicVoting::VoteReclaim.jobs.size).to eq(0)
    end
  end

  context "when a category has voting enabled/disabled" do
    let(:category3) { Fabricate(:category) }
    let(:topic2) { Fabricate(:topic, category: category3) }

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: category1)

      DiscourseTopicVoting::CategorySetting.create!(category: category2)

      DiscourseTopicVoting::CategorySetting.destroy_by(category: category3)

      DiscourseTopicVoting::Vote.create(user: user0, topic: topic0)
      DiscourseTopicVoting::Vote.create(user: user0, topic: topic1)
      DiscourseTopicVoting::Vote.create(user: user0, topic: topic2, archive: true)
    end

    it "reclaims votes when voting is disabled on a category" do
      DiscourseTopicVoting::CategorySetting.destroy_by(category: category1)

      user0.reload

      expect(
        DiscourseTopicVoting::Vote.where(user: user0, archive: false).map(&:topic_id),
      ).to contain_exactly(topic1.id)
      expect(
        DiscourseTopicVoting::Vote.where(user: user0, archive: true).map(&:topic_id),
      ).to contain_exactly(topic0.id, topic2.id)
    end

    it "restores votes when voting is enabled on a category" do
      DiscourseTopicVoting::CategorySetting.create!(category: category3)

      user0.reload

      expect(
        DiscourseTopicVoting::Vote.where(user: user0, archive: false).map(&:topic_id),
      ).to contain_exactly(topic0.id, topic1.id, topic2.id)
      expect(DiscourseTopicVoting::Vote.where(user: user0, archive: true).map(&:topic_id)).to eq([])
    end

    it "is not erroring when topic without category" do
      topic1.category.destroy
      expect(topic1.reload.can_vote?).to be_falsey
    end
  end
end
