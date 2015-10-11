require 'rails_helper'

describe EmailLog do

  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :to_address }
  it { is_expected.to validate_presence_of :email_type }

  let(:user) { Fabricate(:user) }

  context 'after_create' do
    context 'with user' do
      it 'updates the last_emailed_at value for the user' do
        expect {
          user.email_logs.create(email_type: 'blah', to_address: user.email)
          user.reload
        }.to change(user, :last_emailed_at)
      end

      it "doesn't update last_emailed_at if skipped is true" do
        expect {
          user.email_logs.create(email_type: 'blah', to_address: user.email, skipped: true)
          user.reload
        }.to_not change { user.last_emailed_at }
      end
    end
  end

  describe '#count_per_day' do
    it "counts sent emails" do
      user.email_logs.create(email_type: 'blah', to_address: user.email)
      user.email_logs.create(email_type: 'blah', to_address: user.email, skipped: true)
      expect(described_class.count_per_day(1.day.ago, Time.now).first[1]).to eq 1
    end
  end

  describe ".last_sent_email_address" do
    context "when user's email exist in the logs" do
      before do
        user.email_logs.create(email_type: 'signup', to_address: user.email)
        user.email_logs.create(email_type: 'blah', to_address: user.email)
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

end
