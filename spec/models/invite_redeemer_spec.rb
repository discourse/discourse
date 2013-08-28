require 'spec_helper'

describe InviteRedeemer do

  describe '#create_for_email' do
    let(:user) { InviteRedeemer.create_user_for_email('walter.white@email.com') }
    it "should be created correctly" do
      user.username.should == 'walter_white'
      user.name.should == 'walter_white'
      user.should be_active
      user.email.should == 'walter.white@email.com'
    end
  end
end
