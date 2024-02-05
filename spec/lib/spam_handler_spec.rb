# frozen_string_literal: true

require "spam_handler"

RSpec.describe SpamHandler do
  describe "#should_prevent_registration_from_ip?" do
    it "works" do
      # max_new_accounts_per_registration_ip = 0 disables the check
      SiteSetting.max_new_accounts_per_registration_ip = 0

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])

      # only prevents registration for TL0
      SiteSetting.max_new_accounts_per_registration_ip = 2

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])

      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[1])
      expect {
        Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "doesn't limit registrations since there is a TL2+ user with that IP" do
      # setup
      SiteSetting.max_new_accounts_per_registration_ip = 0
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[2])

      # should not limit registration
      SiteSetting.max_new_accounts_per_registration_ip = 1
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
    end

    it "doesn't limit registrations since there is a staff member with that IP" do
      # setup
      SiteSetting.max_new_accounts_per_registration_ip = 0
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
      Fabricate(:moderator, ip_address: "42.42.42.42", trust_level: TrustLevel[0])

      # should not limit registration
      SiteSetting.max_new_accounts_per_registration_ip = 1
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
    end

    it "doesn't limit registrations when the IP is allowlisted" do
      # setup
      SiteSetting.max_new_accounts_per_registration_ip = 0
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
      ScreenedIpAddress.stubs(:is_allowed?).with("42.42.42.42").returns(true)

      # should not limit registration
      SiteSetting.max_new_accounts_per_registration_ip = 1
      Fabricate(:user, ip_address: "42.42.42.42", trust_level: TrustLevel[0])
    end
  end
end
