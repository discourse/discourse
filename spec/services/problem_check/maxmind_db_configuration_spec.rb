# frozen_string_literal: true

RSpec.describe ProblemCheck::MaxmindDbConfiguration do
  subject(:check) { described_class.new }

  context "when `maxmind_license_key` and `maxmind_account_id` global settings are not set" do
    it "does not raise any warning message" do
      expect(check).to be_chill_about_it
    end
  end

  context "when `maxmind_license_key` and `maxmind_account_id` global settings are set" do
    before do
      global_setting :maxmind_license_key, "license_key"
      global_setting :maxmind_account_id, "account_id"
    end

    it "does not raise any warning message" do
      expect(check).to be_chill_about_it
    end
  end

  context "when `maxmind_license_key` global setting is set but not `maxmind_account_id`" do
    it "raises the right warning" do
      global_setting :maxmind_license_key, "license_key"

      expect(check).to have_a_problem.with_priority("low").with_message(
        I18n.t("dashboard.problem.maxmind_db_configuration"),
      )
    end
  end
end
