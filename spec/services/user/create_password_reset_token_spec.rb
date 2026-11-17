# frozen_string_literal: true

RSpec.describe User::CreatePasswordResetToken do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to allow_values("123456", " 123456 ").for(:code) }
    it { is_expected.not_to allow_values("12345", "1234567", "abcdef").for(:code) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:login_code) { EmailLoginCode.generate!(email: user.email, purpose: :password_reset) }
    let(:code) { login_code.code }
    let(:params) { { code: } }
    let(:login_code_id) { login_code.id }
    let(:user_id) { user.id }
    let(:dependencies) { { login_code_id:, user_id: } }

    context "when the contract is invalid" do
      let(:code) { "invalid" }

      it { is_expected.to fail_a_contract }
    end

    context "without a session code" do
      let(:login_code_id) { nil }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code was issued for login" do
      let(:login_code) { EmailLoginCode.generate!(email: user.email) }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code has expired" do
      before { login_code.update!(expires_at: 1.second.ago) }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code has been consumed" do
      before { login_code.consume! }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code has exhausted its attempts" do
      before { login_code.update!(attempts: EmailLoginCode::MAX_ATTEMPTS) }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code is incorrect" do
      let(:code) { (login_code.code.to_i + 1).modulo(1_000_000).to_s.rjust(6, "0") }

      it "rejects the code and records the failed attempt" do
        expect(result).to fail_a_policy(:code_matches)
        expect(login_code.reload.attempts).to eq(1)
        expect(user.email_tokens.where(scope: EmailToken.scopes[:password_reset])).to be_empty
      end
    end

    context "without a session user" do
      let(:user_id) { nil }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the user email has changed" do
      before do
        login_code
        user.update!(email: "changed@example.com")
      end

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the user is staged" do
      before { user.update!(staged: true) }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when staff writes only mode is enabled" do
      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it { is_expected.to fail_a_policy(:can_write) }
    end

    context "when staff writes only mode is enabled for an admin" do
      fab!(:user, :admin)

      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it { is_expected.to run_successfully }
    end

    context "when the code matches" do
      it "consumes the code and creates a password reset token without logging in" do
        expect { result }.to change { user.email_tokens.count }.by(1)
        expect(result).to run_successfully
        expect(result.email_token).to have_attributes(
          user_id: user.id,
          email: user.email,
          scope: EmailToken.scopes[:password_reset],
        )
        expect(login_code.reload.consumed_at).to be_present
        expect(user.user_auth_tokens).to be_empty
      end
    end
  end
end
