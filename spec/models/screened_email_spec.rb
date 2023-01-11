# frozen_string_literal: true

RSpec.describe ScreenedEmail do
  let(:email) { "block@spamfromhome.org" }
  let(:similar_email) { "bl0ck@spamfromhome.org" }

  describe "new record" do
    it "sets a default action_type" do
      expect(ScreenedEmail.create(email: email).action_type).to eq(ScreenedEmail.actions[:block])
    end

    it "last_match_at is null" do
      # If we manually load the table with some emails, we can see whether those emails
      # have ever been blocked by looking at last_match_at.
      expect(ScreenedEmail.create(email: email).last_match_at).to eq(nil)
    end

    it "downcases the email" do
      s = ScreenedEmail.create(email: "SPAMZ@EXAMPLE.COM")
      expect(s.email).to eq("spamz@example.com")
    end
  end

  describe "#block" do
    context "when email is not being blocked" do
      it "creates a new record with default action of :block" do
        record = ScreenedEmail.block(email)
        expect(record).not_to be_new_record
        expect(record.email).to eq(email)
        expect(record.action_type).to eq(ScreenedEmail.actions[:block])
      end

      it "lets action_type be overridden" do
        record = ScreenedEmail.block(email, action_type: ScreenedEmail.actions[:do_nothing])
        expect(record).not_to be_new_record
        expect(record.email).to eq(email)
        expect(record.action_type).to eq(ScreenedEmail.actions[:do_nothing])
      end
    end

    context "when email is already being blocked" do
      let!(:existing) { Fabricate(:screened_email, email: email) }

      it "doesn't create a new record" do
        expect { ScreenedEmail.block(email) }.to_not change { ScreenedEmail.count }
      end

      it "returns the existing record" do
        expect(ScreenedEmail.block(email)).to eq(existing)
      end
    end
  end

  describe "#should_block?" do
    subject { ScreenedEmail.should_block?(email) }

    it "automatically blocks via email canonicalization" do
      SiteSetting.levenshtein_distance_spammer_emails = 0
      ScreenedEmail.block("bad.acTor+1@gmail.com")
      ScreenedEmail.block("bad.actOr+2@gmail.com")

      expect(ScreenedEmail.should_block?("b.a.dactor@gmail.com")).to eq(true)
    end

    it "returns false if a record with the email doesn't exist" do
      expect(subject).to eq(false)
    end

    it "returns true when there is a record with the email" do
      expect(ScreenedEmail.should_block?(email)).to eq(false)
      ScreenedEmail.create(email: email).save
      expect(ScreenedEmail.should_block?(email)).to eq(true)
    end

    it "returns true when there is a record with a similar email" do
      expect(ScreenedEmail.should_block?(email)).to eq(false)
      ScreenedEmail.create(email: similar_email).save
      expect(ScreenedEmail.should_block?(email)).to eq(true)
    end

    it "returns true when it's same email, but all caps" do
      ScreenedEmail.create(email: email).save
      expect(ScreenedEmail.should_block?(email.upcase)).to eq(true)
    end

    shared_examples "when a ScreenedEmail record matches" do
      it "updates statistics" do
        freeze_time do
          expect { subject }.to change { screened_email.reload.match_count }.by(1)
          expect(screened_email.last_match_at).to eq_time(Time.zone.now)
        end
      end
    end

    context "when action_type is :block" do
      let!(:screened_email) do
        Fabricate(:screened_email, email: email, action_type: ScreenedEmail.actions[:block])
      end
      it { is_expected.to eq(true) }
      include_examples "when a ScreenedEmail record matches"
    end

    context "when action_type is :do_nothing" do
      let!(:screened_email) do
        Fabricate(:screened_email, email: email, action_type: ScreenedEmail.actions[:do_nothing])
      end
      it { is_expected.to eq(false) }
      include_examples "when a ScreenedEmail record matches"
    end
  end
end
