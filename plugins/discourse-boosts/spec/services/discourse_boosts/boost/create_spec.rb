# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:raw) }
    it { is_expected.to validate_length_of(:raw).is_at_most(16) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }

    let(:params) { { post_id: post.id, raw: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:raw) { "🎉" }

    context "when contract is invalid" do
      let(:raw) { "" }

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

    context "when user boost limit is reached" do
      before do
        SiteSetting.discourse_boosts_max_per_user_per_post = 1
        Fabricate(:boost, post: post, user: acting_user)
      end

      it { is_expected.to fail_a_policy(:within_user_boost_limit) }
    end

    context "when post boost limit is reached" do
      before do
        SiteSetting.discourse_boosts_max_per_post = 1
        Fabricate(:boost, post: post, user: Fabricate(:user))
      end

      it { is_expected.to fail_a_policy(:within_post_boost_limit) }
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

      it "creates a notification for the post author" do
        expect { result }.to change {
          Notification.where(user: post_author, notification_type: Notification.types[:boost]).count
        }.by(1)
      end

      context "when post author has disabled boost notifications" do
        before { post_author.user_option.update!(boost_notifications_level: 2) }

        it { is_expected.to run_successfully }

        it "does not create a notification" do
          expect { result }.not_to change { Notification.count }
        end
      end
    end
  end
end
