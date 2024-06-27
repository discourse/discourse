# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20240627125112_remove_invalid_csp_script_src_site_setting_values.rb",
        )

RSpec.describe RemoveInvalidCspScriptSrcSiteSettingValues do
  let(:migrate) { described_class.new.up }

  context "when content_security_policy_script_src site setting is present" do
    context "when value is present" do
      let(:hash_1) { "'sha256-QFlnYO2Ll+rgFRKkUmtyRublBc7KFNsbzF7BzoCqjgA='" }
      let(:hash_2) { "'sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC'" }
      let(:prev_value) do
        "'unsafe-inline'|'wasm-unsafe-eval'|example.com|'unsafe-eval'|'sha256-bad+encoded+str=!'|#{hash_1}|#{hash_2}"
      end
      let(:new_value) { "'wasm-unsafe-eval'|'unsafe-eval'|#{hash_1}|#{hash_2}" }
      let!(:site_setting) do
        SiteSetting.create!(
          name: "content_security_policy_script_src",
          data_type: SiteSettings::TypeSupervisor.types[:simple_list],
          value: prev_value,
        )
      end

      it "keeps only valid script src values" do
        silence_stdout { migrate }
        expect(site_setting.reload.value).to eq new_value
      end

      it "creates a new user history tracking the change in values" do
        expect { silence_stdout { migrate } }.to change(UserHistory, :count).by 1
        expect(UserHistory.last).to have_attributes(
          subject: "content_security_policy_script_src",
          admin_only: true,
          action: UserHistory.actions[:change_site_setting],
          previous_value: prev_value,
          new_value:,
        )
      end
    end

    context "when value is default" do
      let!(:site_setting) do
        SiteSetting.create!(
          name: "content_security_policy_script_src",
          data_type: SiteSettings::TypeSupervisor.types[:simple_list],
          value: "",
        )
      end

      it "does not update rows with the default empty string value" do
        expect(site_setting.reload.value).to eq ""
      end

      it "does not create a new user history" do
        expect { silence_stdout { migrate } }.not_to change(UserHistory, :count)
      end
    end
  end

  context "when content_security_policy_script_src site setting is not present" do
    it "does not update" do
      silence_stdout { migrate }
      expect(SiteSetting.exists?(name: "content_security_policy_script_src")).to eq false
    end

    it "does not create a new user history" do
      expect { silence_stdout { migrate } }.not_to change(UserHistory, :count)
    end
  end
end
