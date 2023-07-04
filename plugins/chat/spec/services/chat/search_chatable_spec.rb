# frozen_string_literal: true

RSpec.describe Chat::SearchChatable do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:direct_message__channel_1) do
      fab!(:channel) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }
    end

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { guardian: guardian, target_usernames: %w[lechuck elaine] } }

    context "when all steps pass" do
      it "sets the service result as successful" do
        expect(result).to be_a_success
      end

      it "returns chatables" do
        expect(result.channel.chatable).to have_attributes(
          user_ids: match_array([current_user.id, user_1.id, user_2.id]),
        )
      end
    end

    context "when the term is blank" do
      fab!(:current_user) { Fabricate(:user) }

      before { SiteSetting.direct_message_enabled_groups = Fabricate(:group).id }

      it { is_expected.to fail_a_policy(:can_create_direct_message) }
    end

    context "when the number of target users exceeds chat_max_direct_message_users" do
      before { SiteSetting.chat_max_direct_message_users = 1 }

      it { is_expected.to fail_a_policy(:satisfies_dms_max_users_limit) }

      context "when the user is staff" do
        fab!(:current_user) { Fabricate(:admin) }

        it { is_expected.not_to fail_a_policy(:satisfies_dms_max_users_limit) }
      end
    end

    context "when the actor is not allowing anyone to message them" do
      before { current_user.user_option.update!(allow_private_messages: false) }

      it { is_expected.to fail_a_policy(:actor_allows_dms) }
    end

    context "when one of the target users is ignoring the current user" do
      before do
        IgnoredUser.create!(user: user_1, ignored_user: current_user, expiring_at: 1.day.from_now)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when one of the target users is muting the current user" do
      before { MutedUser.create!(user: user_1, muted_user: current_user) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when one of the target users is disallowing messages" do
      before { user_1.user_option.update!(allow_private_messages: false) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is allowing messages from all but one of the target users" do
      before do
        current_user.user_option.update!(enable_allowed_pm_users: true)
        AllowedPmUser.create!(user: current_user, allowed_pm_user: user_2)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is ignoring one of the target users" do
      before do
        IgnoredUser.create!(user: current_user, ignored_user: user_1, expiring_at: 1.day.from_now)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is muting one of the target users" do
      before { MutedUser.create!(user: current_user, muted_user: user_1) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end
  end
end
