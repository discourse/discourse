require 'spec_helper'

describe ScreenedEmail do

  let(:email) { 'block@spamfromhome.org' }

  describe "new record" do
    it "sets a default action_type" do
      described_class.create(email: email).action_type.should == described_class.actions[:block]
    end

    it "last_match_at is null" do
      # If we manually load the table with some emails, we can see whether those emails
      # have ever been blocked by looking at last_match_at.
      described_class.create(email: email).last_match_at.should be_nil
    end
  end

  describe '#block' do
    context 'email is not being blocked' do
      it 'creates a new record with default action of :block' do
        record = described_class.block(email)
        record.should_not be_new_record
        record.email.should == email
        record.action_type.should == described_class.actions[:block]
      end

      it 'lets action_type be overriden' do
        record = described_class.block(email, action_type: described_class.actions[:do_nothing])
        record.should_not be_new_record
        record.email.should == email
        record.action_type.should == described_class.actions[:do_nothing]
      end
    end

    context 'email is already being blocked' do
      let!(:existing) { Fabricate(:screened_email, email: email) }

      it "doesn't create a new record" do
        expect { described_class.block(email) }.to_not change { described_class.count }
      end

      it "returns the existing record" do
        described_class.block(email).should == existing
      end
    end
  end

  describe '#should_block?' do
    subject { described_class.should_block?(email) }

    it "returns false if a record with the email doesn't exist" do
      subject.should be_false
    end

    shared_examples "when a ScreenedEmail record matches" do
      it "updates statistics" do
        Timecop.freeze(Time.zone.now) do
          expect { subject }.to change { screened_email.reload.match_count }.by(1)
          screened_email.last_match_at.should be_within_one_second_of(Time.zone.now)
        end
      end
    end

    context "action_type is :block" do
      let!(:screened_email) { Fabricate(:screened_email, email: email, action_type: described_class.actions[:block]) }
      it { should be_true }
      include_examples "when a ScreenedEmail record matches"
    end

    context "action_type is :do_nothing" do
      let!(:screened_email) { Fabricate(:screened_email, email: email, action_type: described_class.actions[:do_nothing]) }
      it { should be_false }
      include_examples "when a ScreenedEmail record matches"
    end
  end

end
