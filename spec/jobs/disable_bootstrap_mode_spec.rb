require 'rails_helper'

describe Jobs::DisableBootstrapMode do

  context '.execute' do
    let(:admin) { Fabricate(:admin) }

    before do
      SiteSetting.bootstrap_mode_enabled = true
      SiteSetting.default_trust_level = TrustLevel[1]
      SiteSetting.default_email_digest_frequency = 1440
    end

    it 'does not execute if bootstrap mode is already disabled' do
      SiteSetting.bootstrap_mode_enabled = false
      StaffActionLogger.any_instance.expects(:log_site_setting_change).never
      Jobs::DisableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'turns off bootstrap mode if bootstrap_mode_min_users is set to 0' do
      SiteSetting.bootstrap_mode_min_users = 0
      StaffActionLogger.any_instance.expects(:log_site_setting_change).times(3)
      Jobs::DisableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'does not amend setting that is not in bootstrap state' do
      SiteSetting.bootstrap_mode_min_users = 0
      SiteSetting.default_trust_level = TrustLevel[3]
      StaffActionLogger.any_instance.expects(:log_site_setting_change).twice
      Jobs::DisableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'successfully turns off bootstrap mode' do
      SiteSetting.bootstrap_mode_min_users = 5
      6.times do
        Fabricate(:user)
      end
      StaffActionLogger.any_instance.expects(:log_site_setting_change).times(3)
      Jobs::DisableBootstrapMode.new.execute(user_id: admin.id)
    end
  end
end
