require 'rails_helper'

describe InviteRedeemer do

  describe '#create_for_email' do
    let(:user) { InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White') }
    it "should be created correctly" do
      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user).to be_active
      expect(user.email).to eq('walter.white@email.com')
    end
  end
end
