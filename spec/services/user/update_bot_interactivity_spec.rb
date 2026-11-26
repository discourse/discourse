# frozen_string_literal: true

RSpec.describe User::UpdateBotInteractivity do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }

    it do
      is_expected.to allow_values(true, false, 1, 0, "1", "0", "true", "false", "on", "off").for(
        :interactive_bot,
      )
    end

    it { is_expected.not_to allow_values(nil, "garbage", "", [], [true]).for(:interactive_bot) }

    it "requires an interactivity value" do
      contract = described_class.new(user_id: -10)

      expect(contract).not_to be_valid
      expect(contract.errors).to include(:interactive_bot)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:actor, :admin)
    fab!(:bot) { Fabricate(:bot, interactive_bot: false) }

    let(:guardian) { actor.guardian }
    let(:params) { { user_id: bot.id, interactive_bot: true } }

    context "when the contract is invalid" do
      before { params[:interactive_bot] = "garbage" }

      it "fails without updating the bot or logging an action" do
        expect { result }.to not_change { bot.reload.interactive_bot }.and(
          not_change(UserHistory, :count),
        )
        expect(result).to fail_a_contract
      end
    end

    context "when the bot is missing" do
      before { params[:user_id] = User.minimum(:id) - 1 }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the actor is anonymous" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:can_update_bot_interactivity) }
    end

    context "when the actor is a regular user" do
      fab!(:actor, :user)

      it { is_expected.to fail_a_policy(:can_update_bot_interactivity) }
    end

    context "when the actor is a moderator" do
      fab!(:actor, :moderator)

      it { is_expected.to fail_a_policy(:can_update_bot_interactivity) }
    end

    context "when the target is a human" do
      fab!(:bot, :user)

      it { is_expected.to fail_a_policy(:can_update_bot_interactivity) }
    end

    context "when the target is the system user" do
      before { params[:user_id] = Discourse.system_user.id }

      it { is_expected.to fail_a_policy(:can_update_bot_interactivity) }
    end

    context "when the site is archived" do
      before { SiteSetting.site_archived = true }

      it "fails without updating the bot or logging an action" do
        expect { result }.to not_change { bot.reload.interactive_bot }.and(
          not_change(UserHistory, :count),
        )
        expect(result).to fail_a_policy(:site_not_archived)
      end
    end

    context "when everything is valid" do
      it "persists enabling and disabling interactivity and audits each change" do
        [true, false].each do |enabled|
          expect do
            outcome =
              described_class.call(params: params.merge(interactive_bot: enabled), guardian:)
            expect(outcome).to run_successfully
          end.to change { bot.reload.interactive_bot }
            .from(!enabled)
            .to(enabled)
            .and(change(UserHistory, :count).by(1))

          expect(UserHistory.last).to have_attributes(
            action: UserHistory.actions[:change_bot_interactivity],
            acting_user_id: actor.id,
            target_user_id: bot.id,
            subject: bot.username,
            previous_value: (!enabled).to_s,
            new_value: enabled.to_s,
          )
        end
      end

      it "does not log an unchanged value" do
        params[:interactive_bot] = "false"

        expect { result }.to not_change { bot.reload.interactive_bot }.and(
          not_change(UserHistory, :count),
        )
        expect(result).to run_successfully
      end

      it "persists form-encoded false as false" do
        bot.update!(interactive_bot: true)
        params[:interactive_bot] = "false"

        expect { result }.to change { bot.reload.interactive_bot }.from(true).to(false)
        expect(result).to run_successfully
      end
    end
  end
end
