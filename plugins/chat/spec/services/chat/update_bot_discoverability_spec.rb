# frozen_string_literal: true

RSpec.describe Chat::UpdateBotDiscoverability do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to allow_values(true, false).for(:discoverable) }
    it { is_expected.not_to allow_value(nil).for(:discoverable) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params, guardian: actor.guardian) }

    fab!(:actor, :admin)
    fab!(:bot)

    let(:params) { { user_id: bot.id, discoverable: true } }

    context "when the actor is a moderator" do
      fab!(:actor, :moderator)
      it { is_expected.to fail_a_policy(:can_manage_bots) }
    end

    context "when params are invalid" do
      let(:params) { { user_id: bot.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the target is a human" do
      let(:params) { { user_id: actor.id, discoverable: true } }

      it { is_expected.to fail_to_find_a_model(:bot) }
    end

    context "when the target is the system user" do
      let(:params) { { user_id: Discourse::SYSTEM_USER_ID, discoverable: true } }

      it { is_expected.to fail_to_find_a_model(:bot) }
    end

    context "when enabling discovery" do
      it "lists the bot and logs the change" do
        expect { result }.to change(Chat::DiscoverableBot, :count).by(1).and change(
                UserHistory,
                :count,
              ).by(1)
        expect(result).to run_successfully
        expect(UserHistory.last).to have_attributes(
          custom_type: "chat_bot_discoverability_change",
          subject: bot.username,
          previous_value: "false",
          new_value: "true",
          acting_user_id: actor.id,
        )
      end
    end

    context "when discovery is already enabled" do
      before { Chat::DiscoverableBot.create!(user: bot) }

      it "does not write or log a change" do
        expect { result }.not_to change { [Chat::DiscoverableBot.count, UserHistory.count] }
        expect(result).to run_successfully
      end
    end

    context "when disabling discovery" do
      let(:params) { { user_id: bot.id, discoverable: false } }

      before { Chat::DiscoverableBot.create!(user: bot) }

      it "unlists the bot and logs the change" do
        expect { result }.to change(Chat::DiscoverableBot, :count).by(-1).and change(
                UserHistory,
                :count,
              ).by(1)
        expect(result).to run_successfully
        expect(UserHistory.last).to have_attributes(previous_value: "true", new_value: "false")
      end
    end
  end
end
