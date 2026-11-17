# frozen_string_literal: true

RSpec.describe Dsa::VerifyNoticeEmail do
  describe described_class::Contract, type: :model do
    subject(:contract) do
      described_class.new(email: "alex@example.com", token: "a" * 64, verification_code: "123456")
    end

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:token) }
    it { is_expected.to validate_length_of(:token).is_equal_to(64) }
    it { is_expected.to allow_value("012345").for(:verification_code) }
    it { is_expected.not_to allow_values("12345", "1234567", "12345a").for(:verification_code) }
    it { is_expected.to validate_length_of(:email).is_at_most(254) }

    it "normalizes the email before verification" do
      contract.email = " ALEX@EXAMPLE.COM "

      expect(contract).to be_valid
      expect(contract.email).to eq("alex@example.com")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:email) { "alex@example.com" }
    let(:token) { Dsa::NoticeVerification.create(email) }
    let(:verification_code) { Dsa::NoticeVerification.find(token)[:code] }
    let(:params) { { email:, token:, verification_code: } }

    context "when the contract is invalid" do
      let(:verification_code) { "12345" }

      it { is_expected.to fail_a_contract }
    end

    context "when the code is incorrect" do
      let(:verification_code) do
        Dsa::NoticeVerification.find(token)[:code] == "123456" ? "654321" : "123456"
      end

      it { is_expected.to fail_to_find_a_model(:verification) }
    end

    context "when the code is correct" do
      it "verifies the email without creating a report" do
        expect { result }.not_to change(Dsa::Notice, :count)

        expect(result).to run_successfully
        expect(result.verification).to eq(email:)
        expect(Dsa::NoticeVerification.find(token)).to eq(email:, verified: true)
      end
    end
  end
end
