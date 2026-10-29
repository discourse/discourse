# frozen_string_literal: true

RSpec.describe User::Silence do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_presence_of(:silenced_till) }
    it { is_expected.to validate_length_of(:reason).is_at_most(300) }

    it do
      is_expected.to validate_length_of(:other_user_ids).as_array.is_at_most(
        User::MAX_SIMILAR_USERS,
      )
    end

    it do
      is_expected.to validate_inclusion_of(:post_action).in_array(
        %w[delete delete_replies edit none],
      ).allow_blank
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)

    let(:params) { { user_id:, reason:, silenced_till:, other_user_ids:, message: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:user_id) { user.id }
    let(:other_user_ids) { other_user.id }
    let(:reason) { "spam" }
    let(:message) { "it was spam" }
    let(:silenced_till) { 3.hours.from_now.to_s }

    context "when invalid data is provided" do
      let(:user_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when provided user does not exist" do
      let(:user_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when user is already silenced" do
      fab!(:moderator)

      let(:policy_reason) { result["result.policy.not_silenced_already"].reason }

      before { UserSilencer.silence(user, moderator) }

      it { is_expected.to fail_a_policy(:not_silenced_already) }

      it "says who silenced them" do
        expect(policy_reason).to eq(
          I18n.t(
            "user.already_silenced",
            staff: moderator.username,
            time_ago:
              AgeWords.time_ago_in_words(
                user.silenced_record.created_at,
                true,
                scope: :"datetime.distance_in_words_verbose",
              ),
          ),
        )
      end

      context "when their penalty history was reset" do
        before { user.silenced_record.update!(action: UserHistory.actions[:removed_silence_user]) }

        it "says they are already silenced" do
          expect(policy_reason).to eq(I18n.t("user.already_silenced_without_details"))
        end
      end

      context "when the moderator who silenced them was deleted" do
        before { UserDestroyer.new(admin).destroy(moderator) }

        it "says they are already silenced" do
          expect(policy_reason).to eq(I18n.t("user.already_silenced_without_details"))
        end
      end
    end

    context "when all users cannot be silenced" do
      let(:other_user_ids) { [other_user.id, Fabricate(:admin).id].join(",") }

      it { is_expected.to fail_a_policy(:can_silence_all_users) }
    end

    context "when the user is an anonymous shadow" do
      fab!(:shadow) do
        Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: user) }
      end

      let(:user_id) { shadow.id }

      before { SiteSetting.allow_anonymous_mode = true }

      it "silences the account behind the shadow and emails the shadow" do
        result

        expect(user.reload).to be_silenced
        expect(Jobs::CriticalUserEmail.jobs.map { it["args"].first["user_id"] }).to include(
          shadow.id,
        ).and exclude(user.id)
      end

      context "when silencing the account behind an already silenced shadow" do
        let(:user_id) { user.id }

        before { UserSilencer.silence(shadow, admin) }

        it "says the account is already silenced without naming who silenced the shadow" do
          expect(result).to fail_a_policy(:not_silenced_already)
          expect(result["result.policy.not_silenced_already"].reason).to eq(
            I18n.t("user.already_silenced_without_details"),
          )
        end
      end
    end

    context "when everything's ok" do
      it "checks and applies the penalty under a lock per user" do
        DistributedMutex
          .expects(:synchronize)
          .with("user/silence:user_id:#{user.id}")
          .yields
          .returns(:success)

        expect(result).to run_successfully
      end

      it "silences all provided users" do
        result
        expect([user, other_user].map(&:reload)).to all be_silenced
      end

      it "enqueues jobs to send an email" do
        expect { result }.to change { Jobs::CriticalUserEmail.jobs.size }.by(2)
      end

      it "exposes the full reason in the result object" do
        expect(result[:full_reason]).to eq("spam\n\nit was spam")
      end

      context "when the user's own id is among the other users" do
        let(:other_user_ids) { [user.id, other_user.id].join(",") }

        it "silences them once" do
          events = DiscourseEvent.track_events(:user_silenced) { result }

          expect(events.map { it[:params].first[:user] }).to contain_exactly(user, other_user)
          expect(
            UserHistory.where(target_user: user, action: UserHistory.actions[:silence_user]).count,
          ).to eq(1)
        end
      end

      it "deletes the selected post" do
        post = Fabricate(:post, user:)
        params.merge!(post_id: post.id, post_action: "delete")

        result

        expect(post.reload).to be_trashed
      end
    end
  end
end
