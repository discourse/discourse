# frozen_string_literal: true

RSpec.describe Dsa::RequestNoticeVerification do
  let(:params) { { email: "alex@example.com" } }

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(params) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(254) }
    it { is_expected.not_to allow_value("invalid").for(:email) }
    it { is_expected.not_to allow_value("alex@example.com\r\nBcc: victim@example.com").for(:email) }

    it "normalizes the email before requesting its code" do
      params[:email] = " ALEX@EXAMPLE.COM "

      expect(contract).to be_valid
      expect(contract.email).to eq("alex@example.com")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:dependencies) { { options: { ip_address: "198.51.100.1" } } }

    context "when the contract is invalid" do
      before { params[:email] = nil }

      it "halts before queuing verification" do
        expect { result }.not_to change { Jobs::DsaNoticeVerification.jobs.size }
        expect(result).to fail_a_contract
      end
    end

    context "when rate limits are enabled" do
      before { RateLimiter.enable }

      it "limits notices by email address" do
        email_key = Digest::SHA256.hexdigest(params[:email])
        3.times { RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed! }

        expect { result }.to raise_error(RateLimiter::LimitExceeded)
      end

      it "does not charge notice limits for rejected validation attempts" do
        5.times do
          invalid_result =
            described_class.call(params: params.merge(email: "invalid"), **dependencies)
          expect(invalid_result).to fail_a_contract
        end

        expect(result).to run_successfully
      end

      it "preserves shared notice capacity when an email exceeds its allowance" do
        email_key = Digest::SHA256.hexdigest(params[:email])
        3.times { RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed! }
        99.times { RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed! }
        expect { result }.to raise_error(RateLimiter::LimitExceeded)

        other_reporter_params = params.merge(email: "other@example.com")
        remaining_result =
          described_class.call(
            params: other_reporter_params,
            options: {
              ip_address: "198.51.100.2",
            },
          )
        expect(remaining_result).to run_successfully

        expect do
          described_class.call(
            params: other_reporter_params,
            options: {
              ip_address: "198.51.100.3",
            },
          )
        end.to raise_error(RateLimiter::LimitExceeded)
      end

      it "refunds the email allowance when the site notice limit rejects a notice" do
        email_key = Digest::SHA256.hexdigest(params[:email])
        2.times { RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed! }
        100.times { RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed! }
        expect { result }.to raise_error(RateLimiter::LimitExceeded)

        freeze_time(61.minutes.from_now) do
          accepted_result = described_class.call(params:, **dependencies)
          expect(accepted_result).to run_successfully

          expect do described_class.call(params:, **dependencies) end.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end
      end

      it "limits new notices globally across different IP addresses" do
        99.times { RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed! }
        expect(result).to run_successfully

        expect do
          described_class.call(params:, options: { ip_address: "198.51.100.2" })
        end.to raise_error(RateLimiter::LimitExceeded)
      end

      it "limits notices per IP address" do
        5.times { RateLimiter.new(nil, "dsa-notice-ip-198.51.100.1", 5, 1.hour).performed! }

        expect { result }.to raise_error(RateLimiter::LimitExceeded)
      end
    end

    context "when the notice is valid" do
      it "stores only email verification details and queues its email" do
        expect { result }.not_to change(Dsa::Notice, :count)

        expect(result).to run_successfully
        expect(Dsa::NoticeVerification.find(result.token)).to include(email: params[:email])
        expect(Dsa::NoticeVerification.find(result.token).keys).to contain_exactly(:email, :code)
        expect(Jobs::DsaNoticeVerification.jobs.last["args"].first.except("current_site_id")).to eq(
          "token" => result.token,
        )
        expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
      end
    end
  end
end
