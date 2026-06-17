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

    context "when the email matches an existing user after normalization" do
      let(:email) { "f.oo+anything@gmail.com" }

      before do
        SiteSetting.normalize_emails = true
        user.update!(email: "foo@gmail.com")
      end

      it { is_expected.to run_successfully }

      it "treats it as an existing account" do
        events = DiscourseEvent.track_events(:before_email_login) { result }

        expect(events).to contain_exactly(event_name: :before_email_login, params: [user])
        expect(EmailLoginCode.for_email(email).count).to eq(1)
      end
    end

    context "when the email does not belong to a user" do
      let(:email) { "nobody@example.com" }

      it { is_expected.to run_successfully }

      it "does not generate a code or enqueue an email" do
        expect_not_enqueued_with(job: :send_email_login_code) { result }

        expect(EmailLoginCode.count).to eq(0)
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

      it "does not generate a code, since staged users cannot log in" do
        expect { result }.not_to change(EmailLoginCode, :count)
      end
    end
  end
end
