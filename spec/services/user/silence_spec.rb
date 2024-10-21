# frozen_string_literal: true

require "rails_helper"

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
        %w[delete delete_replies edit],
      ).allow_blank
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:other_user) { Fabricate(:user) }

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
      before { UserSilencer.silence(user, admin) }

      it { is_expected.to fail_a_policy(:not_silenced_already) }
    end

    context "when all users cannot be silenced" do
      let(:other_user_ids) { [other_user.id, Fabricate(:admin).id].join(",") }

      it { is_expected.to fail_a_policy(:can_silence_all_users) }
    end

    context "when everything's ok" do
      before { allow(User::Action::TriggerPostAction).to receive(:call) }

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

      it "triggers a post action" do
        result
        expect(User::Action::TriggerPostAction).to have_received(:call).with(
          guardian:,
          post: nil,
          contract: result[:contract],
        )
      end
    end
  end
end
