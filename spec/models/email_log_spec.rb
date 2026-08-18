# frozen_string_literal: true

RSpec.describe EmailLog do
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :to_address }
  it { is_expected.to validate_presence_of :email_type }

  fab!(:user)

  describe "unique email per post" do
    it "only allows through one email per post" do
      post = Fabricate(:post)
      user = post.user

      ran = EmailLog.unique_email_per_post(post, user) { true }

      expect(ran).to be(true)

      Fabricate(
        :email_log,
        user: user,
        email_type: "blah",
        post_id: post.id,
        to_address: user.email,
        user_id: user.id,
      )

      ran = EmailLog.unique_email_per_post(post, user) { true }

      expect(ran).to be(nil)
    end
  end

  describe "after_create" do
    context "with user" do
      it "updates the last_emailed_at value for the user" do
        expect {
          user.email_logs.create(email_type: "blah", to_address: user.email)
          user.reload
        }.to change(user, :last_emailed_at)
      end
    end
  end

  describe "#reached_max_emails?" do
    before do
      SiteSetting.max_emails_per_day_per_user = 2
      Fabricate(
        :email_log,
        user: user,
        email_type: "blah",
        to_address: user.email,
        user_id: user.id,
      )
      Fabricate(
        :email_log,
        user: user,
        email_type: "blah",
        to_address: user.email,
        user_id: user.id,
        created_at: 3.days.ago,
      )
    end

    it "tracks when max emails are reached" do
      expect(EmailLog.reached_max_emails?(user)).to eq(false)

      Fabricate(
        :email_log,
        user: user,
        email_type: "blah",
        to_address: user.email,
        user_id: user.id,
      )
      expect(EmailLog.reached_max_emails?(user)).to eq(true)
    end

    it "returns false for critical email" do
      Fabricate(
        :email_log,
        user: user,
        email_type: "blah",
        to_address: user.email,
        user_id: user.id,
      )
      expect(EmailLog.reached_max_emails?(user, "forgot_password")).to eq(false)
      expect(EmailLog.reached_max_emails?(user, "confirm_new_email")).to eq(false)
    end
  end

  describe "#count_per_day" do
    it "counts sent emails" do
      Fabricate(:email_log, user: user, email_type: "blah", to_address: user.email)
      expect(described_class.count_per_day(1.day.ago, Time.now).first[1]).to eq 1
    end
  end

  describe ".last_sent_email_address" do
    context "when user's email exist in the logs" do
      before do
        user.email_logs.create(email_type: "signup", to_address: user.email)
        user.email_logs.create(email_type: "blah", to_address: user.email)
        user.reload
      end

      it "the user's last email from the log" do
        expect(user.email_logs.last_sent_email_address).to eq(user.email)
      end
    end

    context "when user's email does not exist email logs" do
      it "returns nil" do
        expect(user.email_logs.last_sent_email_address).to be_nil
      end
    end
  end

  describe "#bounce_key" do
    it "should format the bounce_key correctly" do
      hex = SecureRandom.hex
      email_log = Fabricate(:email_log, user: user, bounce_key: hex)

      raw_key = EmailLog.where(id: email_log.id).pluck("bounce_key::text").first

      expect(raw_key).to_not eq(hex)
      expect(raw_key.delete("-")).to eq(hex)
      expect(EmailLog.find(email_log.id).bounce_key).to eq(hex)
    end
  end

  describe "cc addresses handling" do
    let!(:email_log) { Fabricate(:email_log, user: user) }

    describe "#cc_addresses_split" do
      it "returns empty array if there are no cc addresses" do
        expect(email_log.cc_addresses_split).to eq([])
      end

      it "returns array of cc addresses if there are any" do
        email_log.update(cc_addresses: "test@test.com;test@test2.com")
        expect(email_log.cc_addresses_split).to eq(%w[test@test.com test@test2.com])
      end
    end

    describe "#cc_users" do
      it "returns empty array if there are no cc users" do
        expect(email_log.cc_users).to eq([])
      end

      it "returns array of users if cc_user_ids is present" do
        cc_user = Fabricate(:user, email: "test@test.com")
        cc_user2 = Fabricate(:user, email: "test@test2.com")
        email_log.update(
          cc_addresses: "test@test.com;test@test2.com",
          cc_user_ids: [cc_user.id, cc_user2.id],
        )
        expect(email_log.cc_users).to match_array([cc_user, cc_user2])
      end
    end
  end

  describe ".addressed_to_user scope" do
    let(:user) { Fabricate(:user, email: "test@test.com") }
    before do
      Fabricate(:email_log, to_address: "john@smith.com")
      Fabricate(:email_log, cc_addresses: "jane@jones.com;elle@someplace.org")
      user.reload
    end

    it "returns email logs where the to address matches" do
      user.user_emails.first.update!(email: "john@smith.com")
      expect(EmailLog.addressed_to_user(user).count).to eq(1)
    end

    it "returns email logs where a cc address matches" do
      user.user_emails.first.update!(email: "elle@someplace.org")
      expect(EmailLog.addressed_to_user(user).count).to eq(1)
    end

    it "returns nothing if no emails match" do
      expect(EmailLog.addressed_to_user(user).count).to eq(0)
    end
  end

  describe "bounce_error_code fix before update" do
    fab!(:email_log)

    it "makes sure the bounce_error_code is in the format X.X.X or XXX" do
      email_log.update!(bounce_error_code: "5.1.1")
      expect(email_log.reload.bounce_error_code).to eq("5.1.1")
      email_log.update!(bounce_error_code: "5.2.23")
      expect(email_log.reload.bounce_error_code).to eq("5.2.23")
      email_log.update!(bounce_error_code: "5.0.0 (permanent failure)")
      expect(email_log.reload.bounce_error_code).to eq("5.0.0")
      email_log.update!(bounce_error_code: "422")
      expect(email_log.reload.bounce_error_code).to eq("422")
      email_log.update!(bounce_error_code: "5.2")
      expect(email_log.reload.bounce_error_code).to eq(nil)
      email_log.update!(bounce_error_code: "blah")
      expect(email_log.reload.bounce_error_code).to eq(nil)
    end
  end

  describe "#claim_bounce" do
    fab!(:email_log)

    it "claims an unbounced log and stores the normalized error code" do
      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1 (blah)")).to eq(true)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("5.1.1")
    end

    it "stores a generic error code reflecting the severity when none is reported" do
      expect(email_log.claim_bounce(permanent: false)).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq(EmailLog::BOUNCE_ERROR_CODE_TRANSIENT)
    end

    it "claims an already bounced log only once" do
      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")).to eq(true)
      expect(email_log.claim_bounce(permanent: false, bounce_error_code: "5.1.1")).to eq(false)
      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")).to eq(false)
    end

    it "lets a permanent failure supersede a transient one exactly once" do
      expect(email_log.claim_bounce(permanent: false, bounce_error_code: "4.2.1")).to eq(true)
      expect(email_log.claim_bounce(permanent: false, bounce_error_code: "4.4.7")).to eq(false)

      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq("5.1.1")

      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")).to eq(false)
    end

    it "lets a permanent failure supersede a transient one reported without an error code" do
      expect(email_log.claim_bounce(permanent: false)).to eq(true)
      expect(email_log.claim_bounce(permanent: true)).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq(EmailLog::BOUNCE_ERROR_CODE_PERMANENT)
    end

    it "claims a permanent failure reported with a transient error code only once" do
      diagnostic = "smtp; 450 4.2.1 mailbox is busy"

      expect(email_log.claim_bounce(permanent: true, bounce_error_code: diagnostic)).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq(EmailLog::BOUNCE_ERROR_CODE_PERMANENT)

      expect(email_log.claim_bounce(permanent: true, bounce_error_code: diagnostic)).to eq(false)
      expect(email_log.claim_bounce(permanent: true, bounce_error_code: diagnostic)).to eq(false)
    end

    it "reflects the claim on the record in memory" do
      email_log.claim_bounce(permanent: false, bounce_error_code: "4.2.1")
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("4.2.1")

      email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")
      expect(email_log.bounce_error_code).to eq("5.1.1")
    end

    it "stores a generic code when the reported one contradicts the severity" do
      expect(email_log.claim_bounce(permanent: false, bounce_error_code: "5.1.1")).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq(EmailLog::BOUNCE_ERROR_CODE_TRANSIENT)
    end

    it "escalates a transient claim that reported a permanent code" do
      expect(email_log.claim_bounce(permanent: false, bounce_error_code: "5.1.1")).to eq(true)
      expect(email_log.claim_bounce(permanent: true, bounce_error_code: "5.1.1")).to eq(true)
      expect(email_log.reload.bounce_error_code).to eq("5.1.1")
    end
  end
end
