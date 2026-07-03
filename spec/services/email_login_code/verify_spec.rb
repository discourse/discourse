# frozen_string_literal: true

RSpec.describe EmailLoginCode::Verify do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to allow_values("foo@example.com").for(:email) }
    it { is_expected.not_to allow_values("not-an-email").for(:email) }
    it { is_expected.to allow_values("123456", " 123456 ").for(:code) }
    it { is_expected.not_to allow_values("12345", "1234567", "abcdef").for(:code) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)

    let(:params) { { email:, code: } }
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

      it "burns an attempt" do
        expect { result }.to change { login_code.reload.attempts }.by(1)
      end
    end

    context "when the code is correct for an existing user" do
      it { is_expected.to run_successfully }

      it "returns the user without consuming the code" do
        expect(result[:user]).to eq(user)
        expect(login_code.reload.consumed_at).to be_nil
      end
    end

    context "when the code is correct for an unknown email" do
      let(:email) { "newuser@example.com" }

      it { is_expected.to run_successfully }

      it "returns no user and keeps the code active" do
        expect(result[:user]).to be_nil
        expect(EmailLoginCode.active.for_email(email)).to contain_exactly(login_code)
      end
    end
  end
end
