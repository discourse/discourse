# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:raw) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }

    let(:params) { { post_id: post.id, raw: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:raw) { "🎉" }

    context "when contract is invalid" do
      let(:raw) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when raw is whitespace only" do
      let(:raw) { "   " }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: 0, raw: } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when user cannot boost the post" do
      fab!(:acting_user) { post_author }

      it { is_expected.to fail_a_policy(:can_boost_post) }
    end

    context "when post is in a restricted category" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group: group) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }
      fab!(:post) { Fabricate(:post, topic: private_topic, user: post_author) }

      it { is_expected.to fail_a_policy(:can_boost_post) }
    end

    context "when user is silenced" do
      before { acting_user.update!(silenced_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:can_boost_post) }
    end

    context "when post is deleted" do
      before { post.trash! }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when user boost limit is reached" do
      before { Fabricate(:boost, post: post, user: acting_user) }

      it { is_expected.to fail_a_policy(:user_has_not_boosted_post) }
    end

    context "when post boost limit is reached" do
      before do
        SiteSetting.discourse_boosts_max_per_post = 1
        Fabricate(:boost, post: post, user: Fabricate(:user))
      end

      it { is_expected.to fail_a_policy(:within_post_boost_limit) }
    end

    context "when raw contains a blocked watched word" do
      before { Fabricate(:watched_word, word: "badword", action: WatchedWord.actions[:block]) }

      let(:raw) { "badword" }

      it { is_expected.to fail_a_policy(:not_blocked_by_watched_words) }
    end

    context "when raw contains a censored watched word" do
      before { Fabricate(:watched_word, word: "censorme", action: WatchedWord.actions[:censor]) }

      let(:raw) { "censorme" }

      it "censors the word in the created boost" do
        expect(result).to be_a_success
        expect(DiscourseBoosts::Boost.last.raw).not_to include("censorme")
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the boost" do
        expect { result }.to change { DiscourseBoosts::Boost.count }.by(1)
        expect(DiscourseBoosts::Boost.last).to have_attributes(
          post_id: post.id,
          user_id: acting_user.id,
          raw: "🎉",
        )
      end

      it "cooks the raw content" do
        result
        expect(DiscourseBoosts::Boost.last.cooked).to be_present
      end

      it "publishes a boost_added message to the topic channel" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        boost_message = messages.find { |m| m.data[:type] == :boost_added }
        expect(boost_message).to be_present
        expect(boost_message.data[:id]).to eq(post.id)
        expect(boost_message.data[:boost][:id]).to eq(DiscourseBoosts::Boost.last.id)
        expect(boost_message.data[:boost][:cooked]).to be_present
      end

      it "creates a notification for the post author with expected data" do
        expect { result }.to change {
          Notification.where(user: post_author, notification_type: Notification.types[:boost]).count
        }.by(1)

        notification =
          Notification.where(user: post_author, notification_type: Notification.types[:boost]).last
        expect(notification.data_hash).to include(
          display_username: acting_user.username,
          display_name: acting_user.name,
          boost_raw: "🎉",
          topic_title: topic.title,
        )
      end

      context "when post author has disabled boost notifications" do
        before { post_author.user_option.update!(boost_notifications_level: 2) }

        it { is_expected.to run_successfully }

        it "does not create a notification" do
          expect { result }.not_to change { Notification.count }
        end
      end
    end

    context "when a duplicate key error occurs while creating the boost" do
      before do
        allow(DiscourseBoosts::Boost).to receive(:create).and_raise(
          ActiveRecord::RecordNotUnique.new("duplicate key value violates unique constraint"),
        )
      end

      it "fails the boost model with the duplicate key exception" do
        expect(result).to be_failure
        expect(result["result.model.boost"].exception).to be_a(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
