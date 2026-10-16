# frozen_string_literal: true

RSpec.describe Dsa::SubmitNotice do
  let(:params) do
    {
      content_url: "#{Discourse.base_url}/t/reported/123",
      explanation:
        "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
      name: "Alex Morgan",
      email: "alex@example.com",
      anonymous: false,
      declaration: true,
    }
  end

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(notice: params).notice }

    it { is_expected.to validate_presence_of(:content_url) }
    it { is_expected.to validate_length_of(:explanation).is_at_least(50).is_at_most(20_000) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(254) }
    it { is_expected.not_to allow_value(false).for(:declaration) }
    it { is_expected.not_to allow_value("javascript:alert(1)").for(:content_url) }

    it do
      is_expected.not_to allow_value("https://user:password@example.com/post").for(:content_url)
    end

    it { is_expected.not_to allow_value("invalid").for(:email) }
    it { is_expected.not_to allow_value("alex@example.com\r\nBcc: victim@example.com").for(:email) }

    it "rejects structured values in scalar fields" do
      params[:explanation] = [params[:explanation]]

      expect(contract).not_to be_valid
    end

    it "rejects a notice that is not an object" do
      expect(described_class.new(notice: [params])).not_to be_valid
    end

    it "normalizes contact information" do
      params[:name] = " Alex Morgan "
      params[:email] = " ALEX@EXAMPLE.COM "

      expect(contract).to be_valid
      expect(contract.name).to eq("Alex Morgan")
      expect(contract.email).to eq("alex@example.com")
    end

    it "discards contact information for anonymous notices" do
      params[:anonymous] = true

      expect(contract).to be_valid
      expect(contract.name).to be_nil
      expect(contract.email).to be_nil
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params: { notice: params }, **dependencies) }

    fab!(:admin)
    fab!(:group)

    let(:dependencies) { { options: { ip_address: "198.51.100.1" } } }

    before do
      SiteSetting.dsa_notice_group = group.id.to_s
      group.add(admin)
    end

    context "when the contract is invalid" do
      before { params[:declaration] = nil }

      it "halts before creating or queuing a notice" do
        expect { result }.not_to change(Topic, :count)
        expect(result).to fail_a_contract
        expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
      end
    end

    context "when rate limits are enabled" do
      before { RateLimiter.enable }

      it "limits contact notices by email address" do
        email_key = Digest::SHA256.hexdigest(params[:email])
        3.times { RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed! }

        expect { result }.to raise_error(RateLimiter::LimitExceeded)
      end

      it "does not charge notice limits for rejected validation attempts" do
        5.times do
          invalid_result =
            described_class.call(
              params: {
                notice: params.merge(declaration: false),
              },
              **dependencies,
            )
          expect(invalid_result).to fail_a_contract
        end

        expect(result).to run_successfully
      end

      it "preserves shared notice capacity when an email exceeds its allowance" do
        email_key = Digest::SHA256.hexdigest(params[:email])
        3.times { RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed! }
        99.times { RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed! }
        expect { result }.to raise_error(RateLimiter::LimitExceeded)

        anonymous_params = params.merge(anonymous: true)
        remaining_result =
          described_class.call(
            params: {
              notice: anonymous_params,
            },
            options: {
              ip_address: "198.51.100.2",
            },
          )
        expect(remaining_result).to run_successfully

        expect do
          described_class.call(
            params: {
              notice: anonymous_params,
            },
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
          accepted_result = described_class.call(params: { notice: params }, **dependencies)
          expect(accepted_result).to run_successfully

          expect do
            described_class.call(params: { notice: params }, **dependencies)
          end.to raise_error(RateLimiter::LimitExceeded)
        end
      end

      it "limits new notices globally across different IP addresses" do
        99.times { RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed! }
        expect(result).to run_successfully

        expect do
          described_class.call(params: { notice: params }, options: { ip_address: "198.51.100.2" })
        end.to raise_error(RateLimiter::LimitExceeded)
      end

      it "limits notices per IP address" do
        5.times { RateLimiter.new(nil, "dsa-notice-ip-198.51.100.1", 5, 1.hour).performed! }

        expect { result }.to raise_error(RateLimiter::LimitExceeded)
      end
    end

    context "when the selected group is empty" do
      before { group.remove(admin) }

      it "addresses the PM to admins" do
        expect(result).to run_successfully
        expect(result.notice.post.topic.allowed_groups).to contain_exactly(Group[:admins])
      end
    end

    context "when the selected group was deleted" do
      before { group.destroy! }

      it "addresses the PM to admins" do
        expect(result).to run_successfully
        expect(result.notice.post.topic.allowed_groups).to contain_exactly(Group[:admins])
      end
    end

    context "when the PM cannot be saved" do
      before { PostCreator.stubs(:create!).raises(ActiveRecord::RecordNotSaved) }

      it "halts before queuing the receipt" do
        expect { result }.not_to change(Topic, :count)
        expect(result).to fail_to_find_a_model(:notice)
        expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
      end
    end

    context "when the reporter is anonymous" do
      before { params[:anonymous] = true }

      it "queues no external receipt" do
        expect { result }.not_to change { Jobs::DsaNoticeReceipt.jobs.size }
        expect(result).to run_successfully
      end
    end

    context "when the notice is accepted" do
      it "creates a private PM addressed to the selected group" do
        expect(result).to run_successfully
        expect(result.notice.post.topic).to be_private_message
        expect(result.notice.post.topic.allowed_groups).to contain_exactly(group)
        expect(result.notice.post.topic.allowed_users).to contain_exactly(Discourse.system_user)
      end

      it "queues the external receipt for the saved notice" do
        expect { result }.to change { Jobs::DsaNoticeReceipt.jobs.size }.by(1)
        expect(result).to run_successfully
        expect(Jobs::DsaNoticeReceipt.jobs.last["args"].first["notice_id"]).to eq(result.notice.id)
      end
    end
  end
end
