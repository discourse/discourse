# frozen_string_literal: true

RSpec.describe Jobs::EnableBootstrapMode do
  describe ".execute" do
    fab!(:admin)

    before { SiteSetting.bootstrap_mode_enabled = false }

    it "raises an error when user_id is missing" do
      expect { Jobs::EnableBootstrapMode.new.execute({}) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "does not execute if bootstrap mode is already enabled" do
      SiteSetting.bootstrap_mode_enabled = true
      StaffActionLogger.any_instance.expects(:log_site_setting_change).never
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end

    it "does not turn on bootstrap mode if first admin already exists" do
      first_admin = Fabricate(:admin)
      StaffActionLogger.any_instance.expects(:log_site_setting_change).never
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
    end

    it "does not amend setting that is not in default state" do
      SiteSetting.default_trust_level = TrustLevel[3]
      StaffActionLogger.any_instance.expects(:log_site_setting_change).times(2)
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
      expect(SiteSetting.bootstrap_mode_enabled).to eq(true)
    end

    it "successfully turns on bootstrap mode" do
      Jobs::EnableBootstrapMode.new.execute(user_id: admin.id)
      expect(admin.reload.moderator).to be_truthy
      expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
      expect(SiteSetting.bootstrap_mode_enabled).to eq(true)
    end
  end
end
