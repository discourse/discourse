# frozen_string_literal: true

RSpec.describe SiteSettingsTask do
  describe "export" do
    it "creates a hash of all site settings" do
      sso_url = "https://somewhere.over.com"
      SiteSetting.discourse_connect_url = sso_url
      SiteSetting.enable_discourse_connect = true
      hash = SiteSettingsTask.export_to_hash

      expect(hash).to eq("enable_discourse_connect" => "true", "discourse_connect_url" => sso_url)
    end
  end

  describe "import" do
    it "updates site settings" do
      yml = "title: Test"
      log, counts = SiteSettingsTask.import(yml)
      expect(log[0]).to eq "Changed title FROM: Discourse TO: Test"
      expect(counts[:updated]).to eq 1
      expect(SiteSetting.title).to eq "Test"
    end

    it "updates hidden settings" do
      original_default_theme_id = SiteSetting.default_theme_id.inspect
      yml = "default_theme_id: 999999999"
      log, counts = SiteSettingsTask.import(yml)
      expect(
        log[0],
      ).to eq "Changed default_theme_id FROM: #{original_default_theme_id} TO: 999999999"
      expect(counts[:updated]).to eq(1)
      expect(SiteSetting.default_theme_id).to eq(999_999_999)
    end

    it "won't update a setting that doesn't exist" do
      yml = "fake_setting: foo"
      log, counts = SiteSettingsTask.import(yml)
      expect(log[0]).to eq "NOT FOUND: existing site setting not found for fake_setting"
      expect(counts[:not_found]).to eq 1
    end

    it "will log that an error has occurred" do
      yml = "min_password_length: 0"
      log, counts = SiteSettingsTask.import(yml)
      expect(log[0]).to eq "ERROR: min_password_length: Value must be between 8 and 500."
      expect(counts[:errors]).to eq 1
      expect(SiteSetting.min_password_length).to eq 10
    end
  end
end
