# frozen_string_literal: true

RSpec.describe EmailLoginCode::Request do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(513) }
    it { is_expected.to allow_values("foo@example.com", "Foo.Bar@example.com").for(:email) }
    it { is_expected.not_to allow_values("not-an-email", "foo@").for(:email) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:params) { { email: } }
    let(:dependencies) { { ip_address: "127.0.0.1" } }
    let(:email) { user.email }

    context "when contract isn't valid" do
      let(:email) { "not-an-email" }

      it { is_expected.to fail_a_contract }
    end

    context "when the email belongs to an existing user" do
      it { is_expected.to run_successfully }

      it "generates a login code for the email" do
        expect { result }.to change { EmailLoginCode.for_email(user.email).count }.by(1)
      end

      it "enqueues the login code email" do
        expect_enqueued_with(job: :send_email_login_code, args: { to_address: user.email }) do
          result
        end
      end

      it "triggers the :before_email_login event" do
        events = DiscourseEvent.track_events(:before_email_login) { result }

        expect(events).to contain_exactly(event_name: :before_email_login, params: [user])
      end
    end

    context "when the email only matches an existing user after normalization" do
      let(:email) { "f.oo+anything@gmail.com" }

      before do
        SiteSetting.normalize_emails = true
        user.update!(email: "foo@gmail.com")
      end

      it { is_expected.to run_successfully }

      it "does not treat it as an existing account" do
        events = nil

        expect_not_enqueued_with(job: :send_email_login_code) do
          events = DiscourseEvent.track_events(:before_email_login) { result }
        end

        expect(events).to be_empty
        expect(EmailLoginCode.count).to eq(0)
      end
    end

    context "when the email is unknown and signups are open" do
      let(:email) { "newuser@example.com" }

      it { is_expected.to run_successfully }

      it "generates a login code and enqueues the email" do
        expect_enqueued_with(job: :send_email_login_code, args: { to_address: email }) { result }

        expect(EmailLoginCode.for_email(email).count).to eq(1)
      end

      it "does not trigger the :before_email_login event" do
        events = DiscourseEvent.track_events(:before_email_login) { result }

        expect(events).to be_empty
      end
    end

    context "when the email belongs to a staged user" do
      fab!(:staged_user, :staged)

      let(:email) { staged_user.email }

      it { is_expected.to run_successfully }

      it "treats it as a new registration, not an existing account" do
        events = DiscourseEvent.track_events(:before_email_login) { result }

        expect(events).to be_empty
        expect(EmailLoginCode.for_email(email).count).to eq(1)
      end

      it "does not generate a code when registrations are closed" do
        SiteSetting.allow_new_registrations = false

        expect { result }.not_to change(EmailLoginCode, :count)
        expect(result).to run_successfully
      end
    end

    context "when the email is unknown and registrations are disabled" do
      let(:email) { "newuser@example.com" }

      before { SiteSetting.allow_new_registrations = false }

      it { is_expected.to run_successfully }

      it "does not generate a code or enqueue an email" do
        expect_not_enqueued_with(job: :send_email_login_code) { result }

        expect(EmailLoginCode.count).to eq(0)
      end
    end

    context "when the email is unknown and the site is invite only" do
      let(:email) { "newuser@example.com" }

      before { SiteSetting.invite_only = true }

      it { is_expected.to run_successfully }

      it "does not generate a code" do
        expect { result }.not_to change(EmailLoginCode, :count)
      end
    end

    context "when the email is unknown and an invite code is required" do
      let(:email) { "newuser@example.com" }

      before { SiteSetting.invite_code = "SECRET" }

      it { is_expected.to run_successfully }

      it "does not generate a code" do
        expect { result }.not_to change(EmailLoginCode, :count)
      end
    end

    context "when the email domain is blocked" do
      let(:email) { "newuser@blocked.com" }

      before { SiteSetting.blocked_email_domains = "blocked.com" }

      it { is_expected.to run_successfully }

      it "does not generate a code" do
        expect { result }.not_to change(EmailLoginCode, :count)
      end
    end

    context "when the email is screened" do
      let(:email) { "newuser@example.com" }

      before { Fabricate(:screened_email, email:) }

      it { is_expected.to run_successfully }

      it "does not generate a code" do
        expect { result }.not_to change(EmailLoginCode, :count)
      end
    end
  end
end
