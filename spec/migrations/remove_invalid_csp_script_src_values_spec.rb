# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20240624034354_remove_invalid_csp_script_src_site_setting_values.rb",
        )

RSpec.describe RemoveInvalidCspScriptSrcSiteSettingValues do
  let(:migrate) { described_class.new.up }
  let(:hash_1) { "'sha256-QFlnYO2Ll+rgFRKkUmtyRublBc7KFNsbzF7BzoCqjgA='" }
  let(:hash_2) { "'sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC'" }

  context "when content_security_policy_script_src site setting is present" do
    let!(:site_setting) do
      SiteSetting.create!(
        name: "content_security_policy_script_src",
        data_type: SiteSettings::TypeSupervisor.types[:simple_list],
      )
    end

    it "keeps only valid script src values" do
      site_setting.update!(
        value:
          "'unsafe-inline'|'wasm-unsafe-eval'|example.com|'unsafe-eval'|'sha256-bad+encoded+str=!'|#{hash_1}|#{hash_2}",
      )
      silence_stdout { migrate }
      expect(site_setting.reload.value).to eq(
        "'wasm-unsafe-eval'|'unsafe-eval'|#{hash_1}|#{hash_2}",
      )
    end

    it "does not update rows with the default empty string value" do
      site_setting.update!(value: "")
      silence_stdout { migrate }
      expect(site_setting.reload.value).to eq ""
    end
  end

  context "when content_security_policy_script_src site setting is not present" do
    it "does not update" do
      silence_stdout { migrate }
      expect(SiteSetting.exists?(name: "content_security_policy_script_src")).to eq false
    end
  end
end
