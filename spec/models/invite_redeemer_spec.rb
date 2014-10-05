require 'spec_helper'

describe InviteRedeemer do

  describe '#create_for_email' do
    let(:user) { InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White') }
    it "should be created correctly" do
      user.username.should == 'walter'
      user.name.should == 'Walter White'
      user.should be_active
      user.email.should == 'walter.white@email.com'
    end
  end
end
