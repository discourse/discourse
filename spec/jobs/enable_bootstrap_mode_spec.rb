require 'rails_helper'

describe Jobs::EnableBootstrapMode do

  context '.execute' do
    let(:admin) { Fabricate(:admin) }

    before do
      SiteSetting.bootstrap_mode_enabled = false
    end

    it 'raises an error when user_id is missing' do
      expect { Jobs::EnableBootstrapMode.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'does not execute if bootstrap mode is already enabled' do
      SiteSetting.bootstrap_mode_enabled = true
      StaffActionLogger.any_instance.expects(:log_site_setting_change).never
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'does not turn on bootstrap mode if first admin already exists' do
      first_admin = Fabricate(:admin)
      StaffActionLogger.any_instance.expects(:log_site_setting_change).never
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'does not amend setting that is not in default state' do
      SiteSetting.default_trust_level = TrustLevel[3]
      StaffActionLogger.any_instance.expects(:log_site_setting_change).twice
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end

    it 'successfully turns on bootstrap mode' do
      StaffActionLogger.any_instance.expects(:log_site_setting_change).times(3)
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end
  end
end
