require 'spec_helper'

describe BlockedEmail do

  let(:email) { 'block@spamfromhome.org' }

  describe "new record" do
    it "sets a default action_type" do
      BlockedEmail.create(email: email).action_type.should == BlockedEmail.actions[:block]
    end

    it "last_match_at is null" do
      # If we manually load the table with some emails, we can see whether those emails
      # have ever been blocked by looking at last_match_at.
      BlockedEmail.create(email: email).last_match_at.should be_nil
    end
  end

  describe "#should_block?" do
    subject { BlockedEmail.should_block?(email) }

    it "returns false if a record with the email doesn't exist" do
      subject.should be_false
    end

    shared_examples "when a BlockedEmail record matches" do
      it "updates statistics" do
        Timecop.freeze(Time.zone.now) do
          expect { subject }.to change { blocked_email.reload.match_count }.by(1)
          blocked_email.last_match_at.should be_within_one_second_of(Time.zone.now)
        end
      end
    end

    context "action_type is :block" do
      let!(:blocked_email) { Fabricate(:blocked_email, email: email, action_type: BlockedEmail.actions[:block]) }
      it { should be_true }
      include_examples "when a BlockedEmail record matches"
    end

    context "action_type is :do_nothing" do
      let!(:blocked_email) { Fabricate(:blocked_email, email: email, action_type: BlockedEmail.actions[:do_nothing]) }
      it { should be_false }
      include_examples "when a BlockedEmail record matches"
    end
  end

end
