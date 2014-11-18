require "spec_helper"
require "spam_handler"

describe SpamHandler do

  describe "#should_prevent_registration_from_ip?" do

    it "works" do
      # max_new_accounts_per_registration_ip = 0 disables the check
      SiteSetting.stubs(:max_new_accounts_per_registration_ip).returns(0)

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])

      # only prevents registration for TL0
      SiteSetting.stubs(:max_new_accounts_per_registration_ip).returns(2)

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      -> { Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0]) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "only limit new registrations from an IP if *all* the users from that IP are TL1 or TL0" do
      # setup
      SiteSetting.stubs(:max_new_accounts_per_registration_ip).returns(0)
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[2])

      # should not limit registrations since there is a TL2 user with that IP
      SiteSetting.stubs(:max_new_accounts_per_registration_ip).returns(1)
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
    end

  end

end
