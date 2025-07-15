# frozen_string_literal: true

RSpec.shared_examples "Scorable Type" do
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }
  let(:current_user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }
  let(:third_user) { Fabricate(:user) }
  let(:expected_score) { expected_score }

  describe "#{described_class} updates gamification score" do
    it "has correct total score" do
      DiscourseGamification::GamificationScore.calculate_scores(
        since_date: "2022-1-1",
        only_subclass: described_class,
      )
      DiscourseGamification::LeaderboardCachedView.create_all

      expect(current_user.gamification_score).to eq(expected_score)
    end
  end
end

RSpec.shared_examples "Category Scoped Scorable Type" do
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }
  let(:user) { Fabricate(:user) }
  let(:user_2) { Fabricate(:user) }
  let(:category_allowed) { Fabricate(:category) }
  let(:category_not_allowed) { Fabricate(:category) }
  let(:expected_score) { described_class.score_multiplier }
  let(:after_create_hook) { nil }

  describe "updates gamification score" do
    let!(:create_score) { class_action_fabricator }
    let!(:trigger_after_create_hook) { after_create_hook }
    before { DiscourseGamification::LeaderboardCachedView.create_all }

    it "#{described_class} updates scores for action in the category configured" do
      expect(user.gamification_score).to eq(0)
      SiteSetting.scorable_categories = category_allowed.id.to_s
      DiscourseGamification::GamificationScore.calculate_scores(only_subclass: described_class)
      DiscourseGamification::LeaderboardCachedView.refresh_all
      expect(user.gamification_score).to eq(expected_score)
    end

    it "#{described_class} doesn't updates scores for action in the category configured" do
      expect(user_2.gamification_score).to eq(0)
      SiteSetting.scorable_categories = category_not_allowed.id.to_s
      DiscourseGamification::GamificationScore.calculate_scores(only_subclass: described_class)
      DiscourseGamification::LeaderboardCachedView.refresh_all
      expect(user_2.gamification_score).to eq(0)
    end
  end
end

RSpec.shared_examples "No Score Value" do
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }
  let(:current_user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }
  let(:class_action_fabricator_for_pm) { nil }
  let(:class_action_fabricator_for_deleted_object) { nil }
  let(:class_action_fabricator_for_wiki) { nil }
  let(:class_action_fabricator_for_themselves) { nil }
  let(:after_create_hook) { nil }

  describe "#{described_class} awards no score value" do
    let!(:create_score_for_deleted_object) { class_action_fabricator_for_deleted_object }
    let!(:create_score_for_pm) { class_action_fabricator_for_pm }
    let!(:create_score_for_wiki) { class_action_fabricator_for_wiki }
    let!(:create_score_for_themselves) { class_action_fabricator_for_themselves }
    let!(:trigger_after_create_hook) { after_create_hook }

    it "does not increase user gamification score" do
      DiscourseGamification::GamificationScore.calculate_scores(
        since_date: "2022-1-1",
        only_subclass: described_class,
      )
      DiscourseGamification::LeaderboardCachedView.create_all

      expect(current_user.gamification_score).to eq(0)
    end
  end
end

RSpec.describe ::DiscourseGamification::LikeReceived do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(10, :post, user: current_user)
      Post.all.each { |p| Fabricate(:post_action, post: p) }
    end

    # ten likes received
    let(:expected_score) { 10 }
  end

  it_behaves_like "Category Scoped Scorable Type" do
    let(:topic) { Fabricate(:topic, user: user, category: category_allowed) }
    let(:class_action_fabricator) { Fabricate(:post, user: user, topic: topic) }
    let(:after_create_hook) { Post.all.each { |p| Fabricate(:post_action, post: p) } }

    # 1 like received
    let(:expected_score) { 1 }
  end

  it_behaves_like "No Score Value" do
    # don't count deleted post towards score
    let(:deleted_topic) { Fabricate(:deleted_topic, user: current_user) }
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:post, user: current_user, topic: deleted_topic, deleted_at: Time.now)
    end

    # don't count private message towards score
    let(:private_message_topic) { Fabricate(:private_message_topic) }
    let(:class_action_fabricator_for_pm) do
      Fabricate(:post, user: current_user, topic: private_message_topic)
    end

    let(:after_create_hook) { Post.all.each { |p| Fabricate(:post_action, post: p) } }
  end
end

RSpec.describe ::DiscourseGamification::LikeGiven do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(10, :post, user: other_user)
      Post.all.each do |p|
        Fabricate(:post_action, user: current_user, post: p, post_action_type_id: 2)
      end
      Post
        .all
        .limit(5)
        .each { |p| Fabricate(:post_action, user: third_user, post: p, post_action_type_id: 2) }
    end

    # ten likes given
    let(:expected_score) { 10 }
  end

  it_behaves_like "Category Scoped Scorable Type" do
    let(:topic) { Fabricate(:topic, user: user, category: category_allowed) }
    let(:post) { Fabricate(:post, user: user, topic: topic) }
    let(:class_action_fabricator) { Fabricate(:post_action, user: user, post: post) }

    # one like given
    let(:expected_score) { 1 }
  end

  it_behaves_like "No Score Value" do
    # don't count deleted post towards score
    let(:deleted_topic) { Fabricate(:deleted_topic, user: current_user) }
    let(:post) { Fabricate(:post, topic: deleted_topic, user: current_user, deleted_at: Time.now) }
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:post_action, user: current_user, post: post)
    end

    # don't count private message towards score
    let(:private_message_topic) { Fabricate(:private_message_topic) }
    let(:post_2) { Fabricate(:post, topic: private_message_topic, user: current_user) }
    let(:class_action_fabricator_for_pm) do
      Fabricate(:post_action, user: current_user, post: post_2)
    end
  end
end

RSpec.describe ::DiscourseGamification::PostCreated do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(2, :post, user: current_user, post_number: 2)

      # OP is not counted
      Fabricate(:post, user: current_user, post_number: 1)

      # small action are not counted
      Fabricate(:post, post_type: Post.types[:moderator_action], user: current_user, post_number: 2)

      # hidden posts are not counted
      Fabricate(
        :post,
        user: current_user,
        hidden: true,
        hidden_at: 5.minutes.ago,
        hidden_reason_id: Post.hidden_reasons[:flagged_by_tl3_user],
        post_number: 2,
      )

      # deleted topics are not counted
      deleted_topic = Fabricate(:topic)
      Fabricate(:post, user: current_user, post_number: 2, topic: deleted_topic)
      deleted_topic.destroy!
    end

    let(:expected_score) { 4 }
  end

  it_behaves_like "Category Scoped Scorable Type" do
    let(:topic) { Fabricate(:topic, user: user, category: category_allowed) }
    let(:class_action_fabricator) { Fabricate(:post, topic: topic, user: user, post_number: 2) }

    let(:expected_score) { 2 }
  end

  it_behaves_like "No Score Value" do
    # don't count deleted post towards score
    let(:deleted_topic) { Fabricate(:deleted_topic, user: current_user) }
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:post, topic: deleted_topic, user: current_user, deleted_at: Time.now)
    end

    # don't count wiki post towards score
    let(:class_action_fabricator_for_wiki) do
      Fabricate(:post, topic: deleted_topic, user: current_user) { wiki { true } }
    end
  end
end

RSpec.describe ::DiscourseGamification::DayVisited do
  it_behaves_like "Scorable Type" do
    before do
      (Date.new(2022, 01, 01)..Date.new(2022, 01, 30)).each do |date|
        UserVisit.create(user_id: current_user.id, visited_at: date)
      end
    end

    # thirty days visited
    let(:expected_score) { 30 }
  end
end

RSpec.describe ::DiscourseGamification::PostRead do
  it_behaves_like "Scorable Type" do
    before do
      (Date.new(2022, 01, 01)..Date.new(2022, 01, 30)).each do |date|
        UserVisit.create(user_id: current_user.id, visited_at: date, posts_read: 100)
      end
    end

    # thirty days of reading 5 posts
    let(:expected_score) { 30 }
  end
end

RSpec.describe ::DiscourseGamification::TimeRead do
  it_behaves_like "Scorable Type" do
    before do
      (Date.new(2022, 01, 01)..Date.new(2022, 01, 30)).each do |date|
        UserVisit.create(user_id: current_user.id, time_read: 3600, visited_at: date)
      end
    end

    # thirty days of reading 1 hour
    let(:expected_score) { 30 }
  end
end

RSpec.describe ::DiscourseGamification::FlagCreated do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(10, :reviewable, created_by: current_user) do
        after_create { self.update(status: 1) }
      end
    end

    # ten flags created
    let(:expected_score) { 100 }
  end
end

RSpec.describe ::DiscourseGamification::TopicCreated do
  it_behaves_like "Scorable Type" do
    before { Fabricate.times(10, :topic, user: current_user) }

    # ten topics created
    let(:expected_score) { 50 }
  end

  it_behaves_like "Category Scoped Scorable Type" do
    let(:class_action_fabricator) { Fabricate(:topic, user: user, category: category_allowed) }
  end

  it_behaves_like "No Score Value" do
    # don't count deleted topic towards score
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:deleted_topic, user: current_user)
    end

    # don't count private message towards score
    let(:class_action_fabricator_for_pm) { Fabricate(:private_message_topic) }
  end
end

RSpec.describe ::DiscourseGamification::UserInvited do
  it_behaves_like "Scorable Type" do
    before do
      stub_request(
        :get,
        "http://local.hub:3000/api/customers/-1/account?access_token&admin_count=0&moderator_count=0",
      ).with(
        headers: {
          "Accept" => "application/json, application/vnd.discoursehub.v1",
          "Host" => "local.hub:3000",
          "Referer" => "http://test.localhost",
        },
      ).to_return(status: 200, body: "", headers: {})
      Fabricate.times(10, :invite, invited_by: current_user) do
        after_create { self.update(redemption_count: 1) }
      end
    end

    # ten users invited
    let(:expected_score) { 100 }
  end
end

RSpec.describe ::DiscourseGamification::ChatReactionReceived do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(10, :chat_message, user: current_user)
      Chat::Message.all.each { |m| Fabricate(:chat_message_reaction, chat_message: m) }
    end

    # ten reactions recieved
    let(:expected_score) { 10 }
  end

  it_behaves_like "No Score Value" do
    # don't count reaction on deleted message towards score
    let(:message1) { Fabricate(:chat_message, user: current_user, deleted_at: Time.now) }
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:chat_message_reaction, chat_message: message1)
    end

    # don't count chat reaction by themselves towards score
    let(:message2) { Fabricate(:chat_message, user: current_user) }
    let(:class_action_fabricator_for_themselves) do
      Fabricate(:chat_message_reaction, chat_message: message2, user: current_user)
    end
  end
end

RSpec.describe ::DiscourseGamification::ChatReactionGiven do
  it_behaves_like "Scorable Type" do
    before do
      Fabricate.times(10, :chat_message, user: other_user)
      Chat::Message.all.each do |m|
        Fabricate(:chat_message_reaction, user: current_user, chat_message: m)
      end
      Chat::Message
        .all
        .limit(5)
        .each { |m| Fabricate(:chat_message_reaction, user: third_user, chat_message: m) }
    end

    # ten reactions given
    let(:expected_score) { 10 }
  end

  it_behaves_like "No Score Value" do
    # don't count reaction on deleted message towards score
    let(:message1) { Fabricate(:chat_message, user: other_user, deleted_at: Time.now) }
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:chat_message_reaction, chat_message: message1, user: current_user)
    end

    # don't count chat reaction by themselves towards score
    let(:message2) { Fabricate(:chat_message, user: current_user) }
    let(:class_action_fabricator_for_themselves) do
      Fabricate(:chat_message_reaction, chat_message: message2, user: current_user)
    end
  end
end

RSpec.describe ::DiscourseGamification::ChatMessageCreated do
  it_behaves_like "Scorable Type" do
    before { Fabricate.times(10, :chat_message, user: current_user) }

    # ten messages created
    let(:expected_score) { 10 }
  end

  it_behaves_like "No Score Value" do
    # don't count deleted post message score
    let(:class_action_fabricator_for_deleted_object) do
      Fabricate(:chat_message, user: current_user, deleted_at: Time.now)
    end

    # don't count chat by themselves towards score
    let(:dm_channel) { Fabricate(:direct_message_channel, users: [current_user]) }
    let(:class_action_fabricator_for_themselves) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: current_user)
    end
  end
end
