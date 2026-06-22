# frozen_string_literal: true

RSpec.describe EmailLoginCode::Redeem do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.not_to allow_values("12345", "abcdef").for(:code) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:params) { { email:, code: } }
    let(:dependencies) { { ip_address: "127.0.0.1" } }
    let(:email) { user.email }

    let!(:login_code) { EmailLoginCode.generate!(email:) }

    let(:code) { login_code.code }

    context "when contract isn't valid" do
      let(:code) { "12345" }

      it { is_expected.to fail_a_contract }
    end

    context "when there is no active code for the email" do
      before { login_code.consume! }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code is wrong" do
      let(:code) { login_code.code == "000000" ? "000001" : "000000" }

      it { is_expected.to fail_a_policy(:code_matches) }
    end

    context "when the email does not belong to a user" do
      let(:email) { "nobody@example.com" }

      it { is_expected.to fail_to_find_a_model(:user) }

      it "does not consume the code" do
        expect { result }.not_to change { login_code.reload.consumed_at }
      end
    end

    context "when the email belongs to an existing active user" do
      it { is_expected.to run_successfully }

      it "returns the user and consumes the code" do
        expect(result[:user]).to eq(user)
        expect(login_code.reload.consumed_at).to be_present
      end
    end

    context "when the email belongs to an existing inactive user" do
      fab!(:user) { Fabricate(:user, active: false) }

      it { is_expected.to run_successfully }

      it "activates the user and consumes the code" do
        expect(result[:user].id).to eq(user.id)
        expect(user.reload).to be_active
        expect(login_code.reload.consumed_at).to be_present
      end
    end
  end
end
