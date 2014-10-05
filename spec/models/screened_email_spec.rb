require 'spec_helper'

describe ScreenedEmail do

  let(:email) { 'block@spamfromhome.org' }
  let(:similar_email) { 'bl0ck@spamfromhome.org' }

  describe "new record" do
    it "sets a default action_type" do
      ScreenedEmail.create(email: email).action_type.should == ScreenedEmail.actions[:block]
    end

    it "last_match_at is null" do
      # If we manually load the table with some emails, we can see whether those emails
      # have ever been blocked by looking at last_match_at.
      ScreenedEmail.create(email: email).last_match_at.should == nil
    end

    it "downcases the email" do
      s = ScreenedEmail.create(email: 'SPAMZ@EXAMPLE.COM')
      s.email.should == 'spamz@example.com'
    end
  end

  describe '#block' do
    context 'email is not being blocked' do
      it 'creates a new record with default action of :block' do
        record = ScreenedEmail.block(email)
        record.should_not be_new_record
        record.email.should == email
        record.action_type.should == ScreenedEmail.actions[:block]
      end

      it 'lets action_type be overriden' do
        record = ScreenedEmail.block(email, action_type: ScreenedEmail.actions[:do_nothing])
        record.should_not be_new_record
        record.email.should == email
        record.action_type.should == ScreenedEmail.actions[:do_nothing]
      end
    end

    context 'email is already being blocked' do
      let!(:existing) { Fabricate(:screened_email, email: email) }

      it "doesn't create a new record" do
        expect { ScreenedEmail.block(email) }.to_not change { ScreenedEmail.count }
      end

      it "returns the existing record" do
        ScreenedEmail.block(email).should == existing
      end
    end
  end

  describe '#should_block?' do
    subject { ScreenedEmail.should_block?(email) }

    it "returns false if a record with the email doesn't exist" do
      subject.should == false
    end

    it "returns true when there is a record with the email" do
      ScreenedEmail.should_block?(email).should == false
      ScreenedEmail.create(email: email).save
      ScreenedEmail.should_block?(email).should == true
    end

    it "returns true when there is a record with a similar email" do
      ScreenedEmail.should_block?(email).should == false
      ScreenedEmail.create(email: similar_email).save
      ScreenedEmail.should_block?(email).should == true
    end

    it "returns true when it's same email, but all caps" do
      ScreenedEmail.create(email: email).save
      ScreenedEmail.should_block?(email.upcase).should == true
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
      let!(:screened_email) { Fabricate(:screened_email, email: email, action_type: ScreenedEmail.actions[:block]) }
      it { should == true }
      include_examples "when a ScreenedEmail record matches"
    end

    context "action_type is :do_nothing" do
      let!(:screened_email) { Fabricate(:screened_email, email: email, action_type: ScreenedEmail.actions[:do_nothing]) }
      it { should == false }
      include_examples "when a ScreenedEmail record matches"
    end
  end

end
