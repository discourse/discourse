require 'spec_helper'

describe EmailLog do

  it { should belong_to :user }

  it { should validate_presence_of :to_address }
  it { should validate_presence_of :email_type }


  context 'after_create' do

    context "reply_key" do

      context "with reply by email enabled" do
        before do
          SiteSetting.expects(:reply_by_email_enabled).returns(true)
        end

        context 'generates a reply key' do
          let(:reply_key) { Fabricate(:email_log).reply_key }

          it "has a reply key" do
            expect(reply_key).to be_present
            expect(reply_key.size).to eq(32)
          end
        end
      end

      context "with reply by email disabled" do
        before do
          SiteSetting.expects(:reply_by_email_enabled).returns(false)
        end

        context 'generates a reply key' do
          let(:reply_key) { Fabricate(:email_log).reply_key }

          it "has no reply key" do
            expect(reply_key).to be_blank
          end
        end
      end

    end


    context 'with user' do
      let(:user) { Fabricate(:user) }

      it 'updates the last_emailed_at value for the user' do
        lambda {
          user.email_logs.create(email_type: 'blah', to_address: user.email)
          user.reload
        }.should change(user, :last_emailed_at)
      end
    end

  end

end
