# frozen_string_literal: true

RSpec.describe Dsa::SubmitNotice do
  let(:notice) do
    {
      content_url: "#{Discourse.base_url}/t/reported/123",
      explanation:
        "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
      name: "Alex Morgan",
      email: "alex@example.com",
      declaration: true,
    }
  end

  describe described_class::Contract, type: :model do
    context "with notice fields" do
      subject(:contract) { described_class.new(notice: notice).notice }

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

      it do
        is_expected.not_to allow_value("alex@example.com\r\nBcc: victim@example.com").for(:email)
      end

      it "rejects structured values in scalar fields" do
        notice[:explanation] = [notice[:explanation]]

        expect(contract).not_to be_valid
      end

      it "rejects a notice that is not an object" do
        expect(described_class.new(notice: [notice])).not_to be_valid
      end

      it "normalizes contact information" do
        notice[:name] = " Alex Morgan "
        notice[:email] = " ALEX@EXAMPLE.COM "

        expect(contract).to be_valid
        expect(contract.name).to eq("Alex Morgan")
        expect(contract.email).to eq("alex@example.com")
      end

      it "requires contact information when a client requests anonymity" do
        notice.merge!(anonymous: true, name: nil, email: nil)

        expect(contract).not_to be_valid
        expect(contract.errors.attribute_names).to include(:name, :email)
      end
    end

    context "with verification fields" do
      subject(:contract) { described_class.new(notice:, token: "a" * 64) }

      it { is_expected.to validate_presence_of(:token) }
      it { is_expected.to validate_length_of(:token).is_equal_to(64) }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:admin)
    fab!(:group)

    let(:token) do
      pending_token = Dsa::NoticeVerification.create(notice[:email])
      code = Dsa::NoticeVerification.find(pending_token)[:code]
      Dsa::NoticeVerification.verify(token: pending_token, email: notice[:email], code:)
      pending_token
    end
    let(:params) { { notice:, token: } }

    before do
      SiteSetting.dsa_notice_group = group.id.to_s
      group.add(admin)
    end

    context "when the token is invalid" do
      let(:token) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the verification has expired" do
      let(:token) { "a" * 64 }

      it "creates no notice and reports a missing submission" do
        expect { result }.not_to change(Dsa::Notice, :count)
        expect(result).to fail_to_find_a_model(:verification)
        expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
      end
    end

    context "when the email code has not been verified" do
      let(:token) { Dsa::NoticeVerification.create(notice[:email]) }

      it { is_expected.to fail_to_find_a_model(:verification) }
    end

    context "when the verification has already been used" do
      before { described_class.call(params:) }

      it "creates no duplicate notice" do
        expect { result }.not_to change(Dsa::Notice, :count)
        expect(result).to fail_to_find_a_model(:verification)
      end
    end

    context "when the verification belongs to another email" do
      before do
        token
        notice[:email] = "replacement@example.com"
      end

      it "creates no notice for an unverified reporter" do
        expect { result }.not_to change(Dsa::Notice, :count)
        expect(result).to fail_to_find_a_model(:verification)
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
