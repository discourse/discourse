require 'spec_helper'

describe EmailLog do

  it { should belong_to :user }
  it { should validate_presence_of :to_address }
  it { should validate_presence_of :email_type }

  context 'after_create' do

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
