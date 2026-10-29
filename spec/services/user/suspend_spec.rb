# frozen_string_literal: true

RSpec.describe User::Suspend do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_presence_of(:suspend_until) }
    it { is_expected.to validate_length_of(:reason).is_at_most(300) }

    it do
      is_expected.to validate_length_of(:other_user_ids).as_array.is_at_most(
        User::MAX_SIMILAR_USERS,
      )
    end

    it do
      is_expected.to validate_inclusion_of(:post_action).in_array(
        %w[delete delete_replies delete_all edit none],
      ).allow_blank
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)

    let(:params) { { user_id:, reason:, suspend_until:, other_user_ids:, message: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:user_id) { user.id }
    let(:other_user_ids) { other_user.id }
    let(:reason) { "spam" }
    let(:message) { "it was spam" }
    let(:suspend_until) { 3.hours.from_now.to_s }

    context "when invalid data is provided" do
      let(:user_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when provided user does not exist" do
      let(:user_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when user is already suspended" do
      fab!(:moderator)

      let(:policy_reason) { result["result.policy.not_suspended_already"].reason }

      before do
        UserSuspender.new(user, by_user: moderator, suspended_till: suspend_until, reason:).suspend
      end

      it { is_expected.to fail_a_policy(:not_suspended_already) }

      it "says who suspended them" do
        expect(policy_reason).to eq(
          I18n.t(
            "user.already_suspended",
            staff: moderator.username,
            time_ago:
              AgeWords.time_ago_in_words(
                user.suspend_record.created_at,
                true,
                scope: :"datetime.distance_in_words_verbose",
              ),
          ),
        )
      end

      context "when their penalty history was reset" do
        before { user.suspend_record.update!(action: UserHistory.actions[:removed_suspend_user]) }

        it "says they are already suspended" do
          expect(policy_reason).to eq(I18n.t("user.already_suspended_without_details"))
        end
      end

      context "when the moderator who suspended them was deleted" do
        before { UserDestroyer.new(admin).destroy(moderator) }

        it "says they are already suspended" do
          expect(policy_reason).to eq(I18n.t("user.already_suspended_without_details"))
        end
      end
    end

    context "when the account behind an anonymous shadow is suspended" do
      fab!(:shadow) do
        Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: user) }
      end

      let(:user_id) { shadow.id }
      let(:other_user_ids) { nil }

      before do
        SiteSetting.allow_anonymous_mode = true
        UserSuspender.new(user, by_user: admin, suspended_till: suspend_until, reason:).suspend
      end

      it "says the shadow is already suspended without naming who suspended the account" do
        expect(result).to fail_a_policy(:not_suspended_already)
        expect(result["result.policy.not_suspended_already"].reason).to eq(
          I18n.t("user.already_suspended_without_details"),
        )
      end
    end

    context "when all users cannot be suspended" do
      let(:other_user_ids) { [other_user.id, Fabricate(:admin).id].join(",") }

      it { is_expected.to fail_a_policy(:can_suspend_all_users) }
    end

    context "when everything's ok" do
      it "checks and applies the penalty under a lock per user" do
        DistributedMutex
          .expects(:synchronize)
          .with("user/suspend:user_id:#{user.id}")
          .yields
          .returns(:success)

        expect(result).to run_successfully
      end

      it "suspends all provided users" do
        result
        expect([user, other_user].map(&:reload)).to all be_suspended
      end

      it "deletes the selected post" do
        post = Fabricate(:post, user:)
        params.merge!(post_id: post.id, post_action: "delete")

        result

        expect(post.reload).to be_trashed
      end

      it "exposes the full reason in the result object" do
        expect(result[:full_reason]).to eq("spam\n\nit was spam")
      end

      context "when the user's own id is among the other users" do
        let(:other_user_ids) { [user.id, other_user.id].join(",") }

        it "suspends them once" do
          events = DiscourseEvent.track_events(:user_suspended) { result }

          expect(events.map { it[:params].first[:user] }).to contain_exactly(user, other_user)
          expect(
            UserHistory.where(target_user: user, action: UserHistory.actions[:suspend_user]).count,
          ).to eq(1)
        end
      end
    end
  end
end
