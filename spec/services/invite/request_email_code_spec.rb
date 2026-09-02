# frozen_string_literal: true

RSpec.describe Invite::RequestEmailCode do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:invite_key) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:invite) { Fabricate(:invite, email: "invited@example.com") }

    let(:params) { { invite_key: invite.invite_key, email: supplied_email } }
    let(:dependencies) { { ip_address: "127.0.0.1" } }
    let(:email) { invite.email }
    let(:supplied_email) { email }

    context "when the contract isn't valid" do
      let(:params) { { invite_key: "" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the invite cannot be found" do
      let(:params) { { invite_key: "missing", email: } }

      it { is_expected.to fail_to_find_a_model(:invite) }
    end

    context "when the invite has expired" do
      before { invite.update!(expires_at: 1.day.ago) }

      it { is_expected.to fail_to_find_a_model(:invite) }
    end

    context "when the supplied email does not match the email invite" do
      let(:supplied_email) { "attacker@example.com" }

      it { is_expected.to run_successfully }

      it "sends the code to the invite's email" do
        expect { result }.to change { EmailLoginCode.for_email(email).count }.by(1).and(
          not_change { EmailLoginCode.for_email(supplied_email).count },
        )
      end
    end

    context "when an invite link has an invalid email" do
      fab!(:invite) { Fabricate(:invite, email: nil) }

      let(:supplied_email) { "not-an-email" }

      it { is_expected.to fail_a_policy(:email_can_redeem_invite) }
    end

    context "when an invite link is restricted to another domain" do
      fab!(:invite) { Fabricate(:invite, email: nil, domain: "allowed.example") }

      let(:supplied_email) { "invited@blocked.example" }

      it { is_expected.to fail_a_policy(:email_can_redeem_invite) }
    end

    context "when the registration IP has reached its account limit" do
      let(:ip_address) { "192.0.2.1" }
      let(:dependencies) { { ip_address: } }

      before do
        Fabricate(:user, ip_address:, trust_level: TrustLevel[0])
        SiteSetting.max_new_accounts_per_registration_ip = 1
      end

      it { is_expected.to fail_a_policy(:can_register_from_ip) }

      it "does not create a code" do
        expect { result }.not_to change { EmailLoginCode.count }
      end
    end

    context "when the email belongs to an existing user at a limited IP" do
      fab!(:user) { Fabricate(:user, email: "invited@example.com") }

      let(:ip_address) { "192.0.2.1" }
      let(:dependencies) { { ip_address: } }

      before do
        Fabricate(:user, ip_address:, trust_level: TrustLevel[0])
        SiteSetting.max_new_accounts_per_registration_ip = 1
      end

      it { is_expected.to run_successfully }

      it "triggers the email-login extension event" do
        events = DiscourseEvent.track_events(:before_email_login) { result }

        expect(events).to contain_exactly(event_name: :before_email_login, params: [user])
      end
    end

    context "when an existing user's email domain is blocked" do
      fab!(:user) { Fabricate(:user, email: "invited@example.com") }

      before { SiteSetting.blocked_email_domains = "example.com" }

      it { is_expected.to run_successfully }
    end

    context "when the email invite is redeemable" do
      it { is_expected.to run_successfully }

      it "creates a code and enqueues its email" do
        expect_enqueued_with(job: :send_email_login_code, args: { to_address: email }) do
          expect { result }.to change { EmailLoginCode.for_email(email).count }.by(1)
        end
      end
    end

    context "when a domain-scoped invite link is redeemable" do
      fab!(:invite) { Fabricate(:invite, email: nil, domain: "example.com") }

      let(:email) { "invited@example.com" }
      let(:supplied_email) { email }

      it { is_expected.to run_successfully }
    end
  end
end
